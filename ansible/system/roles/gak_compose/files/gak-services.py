"""Update rootless Compose projects discovered under the services root.

Each project directory holding a compose.yaml is its own source of truth: the
image channels come from the definition, and an optional top-level `x-update`
mapping declares the project's pre-update gate and readiness probe. Nothing here
carries a list of applications, and boot selection is a separate concern.
An explicit prepared image ID can move a declared reference without a pull.

The Compose provider parses the definition; this program reads the provider's
normalized output with a safe YAML loader and validates it against a small
closed schema. The normalized document carries every expanded service
environment, so it stays in memory: diagnostics name the key that was wrong and
never the value that was in it.

Trust boundary: a Compose file under the services root is user-owned
configuration deployed by Ansible, and the hooks it names run with the invoking
user's privileges. Hooks are argument lists executed directly, never through a
shell, and the first element must be an existing executable file named by
absolute path. Nothing is fetched or interpreted from a registry.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

import yaml

PROGRAM = "gak-services"
COMPOSE_BASENAME = "compose.yaml"
EXTENSION_KEY = "x-update"
WORKING_DIR_LABEL = "com.docker.compose.project.working_dir"
INSPECT_FORMAT = ('{"status":{{json .State.Status}},"restarts":{{.RestartCount}},'
                  '"image":{{json .Image}},"service":'
                  '{{json (index .Config.Labels "com.docker.compose.service")}}}')

# Provider selection and project scoping must come from the definition and the
# declared profiles, never from the environment a caller happens to carry.
DISCARDED_ENVIRONMENT = (
    "PODMAN_COMPOSE_PROVIDER",
    "COMPOSE_FILE",
    "COMPOSE_PROFILES",
    "COMPOSE_PROJECT_NAME",
    "COMPOSE_PATH_SEPARATOR",
)


def setting(name: str, default: str) -> str:
    return os.environ.get(name) or default


def positive_setting(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        value = int(raw)
    except ValueError:
        raise Fatal(f"{name} must be a whole number of seconds") from None
    if value < 0:
        raise Fatal(f"{name} must not be negative")
    return value


class Fatal(Exception):
    """An error that stops the run before anything was changed."""


class Usage(Exception):
    """A malformed invocation."""


class ProjectFailure(Exception):
    """A failure attributable to one project, after mutation may have begun."""


class Timeout(Exception):
    def __init__(self, what: str, seconds: float) -> None:
        super().__init__(f"{what} exceeded its {seconds:g}s bound")


def note(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(f"{PROGRAM}: {message}", file=sys.stderr, flush=True)


def short_id(value: str) -> str:
    return value.removeprefix("sha256:")[:12]


def normalize_id(value: str) -> str:
    return value.removeprefix("sha256:")


# --- bounded subprocesses ---------------------------------------------------

_LIVE: list[subprocess.Popen] = []


def stop_process(proc: subprocess.Popen, grace: float = 10.0) -> None:
    """Terminate a child and everything it started, then reap it."""
    # The group id survives its leader when a descendant still holds a pipe.
    group = proc.pid
    try:
        os.killpg(group, signal.SIGTERM)
    except ProcessLookupError:
        proc.wait()
        return
    deadline = time.monotonic() + grace
    while time.monotonic() < deadline:
        proc.poll()
        try:
            os.killpg(group, 0)
        except ProcessLookupError:
            proc.wait()
            return
        time.sleep(0.05)
    try:
        os.killpg(group, signal.SIGKILL)
    except ProcessLookupError:
        pass
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass


def stop_live_processes() -> None:
    for proc in list(_LIVE):
        stop_process(proc)


@dataclass
class Result:
    status: int
    stdout: str
    stderr: str


def run(
    argv: list[str],
    *,
    timeout: float,
    what: str,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    capture: bool = True,
) -> Result:
    """Run one command in its own process group under a hard time bound.

    A child that outlives its bound is stopped as a group, so a hook that forks
    cannot leave the updater waiting while it still holds the update lock.
    """
    pipe = subprocess.PIPE if capture else None
    try:
        proc = subprocess.Popen(
            argv,
            cwd=str(cwd) if cwd else None,
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=pipe,
            stderr=pipe,
            start_new_session=True,
            text=True,
        )
    except FileNotFoundError:
        raise Fatal(f"required command is not on PATH: {argv[0]}") from None
    except PermissionError:
        raise Fatal(f"required command is not executable: {argv[0]}") from None

    _LIVE.append(proc)
    try:
        try:
            stdout, stderr = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            stop_process(proc)
            try:
                stdout, stderr = proc.communicate(timeout=5)
            except subprocess.TimeoutExpired:
                stdout, stderr = "", ""
            raise Timeout(what, timeout) from None
    finally:
        if proc in _LIVE:
            _LIVE.remove(proc)
    return Result(proc.returncode, stdout or "", stderr or "")


# --- the declared runtime ---------------------------------------------------


@dataclass
class Runtime:
    podman: str
    env: dict[str, str]
    inspect_timeout: int
    pull_timeout: int
    recreate_timeout: int
    provider_timeout: int
    hook_timeout: int
    probe_timeout: int
    readiness_interval: float
    settle_seconds: float
    show_provider_errors: bool
    show_hook_output: bool

    def podman_argv(self, *arguments: str) -> list[str]:
        return [self.podman, *arguments]


def declared_path(home_profile: Path, system_profile: Path, privileged: Path) -> str:
    """Put the declared directories ahead of an inherited PATH, in order.

    A directory that is already present later in the inherited PATH is moved to
    the front rather than left where it is, so a decoy earlier in PATH cannot
    win. The privileged directory comes first because cold rootless namespace
    setup resolves its mapping helpers there.
    """
    declared = [privileged, home_profile / "bin", system_profile / "bin"]
    ordered = [str(entry) for entry in declared if entry.is_dir()]
    seen = set(ordered)
    for entry in os.environ.get("PATH", "").split(os.pathsep):
        if entry and entry not in seen:
            ordered.append(entry)
            seen.add(entry)
    return os.pathsep.join(ordered)


def build_runtime() -> Runtime:
    home = Path(os.environ["HOME"])
    home_profile = Path(setting("GAK_SERVICES_HOME_PROFILE", str(home / ".guix-home/profile")))
    system_profile = Path(setting("GAK_SERVICES_SYSTEM_PROFILE", "/run/current-system/profile"))
    privileged = Path(setting("GAK_SERVICES_PRIVILEGED_BIN", "/run/privileged/bin"))

    env = dict(os.environ)
    env["PATH"] = declared_path(home_profile, system_profile, privileged)
    for name in DISCARDED_ENVIRONMENT:
        env.pop(name, None)
    provider = home_profile / "bin/podman-compose"
    if provider.is_file():
        env["PODMAN_COMPOSE_PROVIDER"] = str(provider)
    # subprocess resolves a bare command name through this process's PATH
    # rather than the child environment's, so both have to carry the same value.
    os.environ["PATH"] = env["PATH"]

    runtime = Runtime(
        podman=setting("GAK_COMPOSE_PODMAN", "podman"),
        env=env,
        inspect_timeout=positive_setting("GAK_SERVICES_INSPECT_TIMEOUT", 60),
        pull_timeout=positive_setting("GAK_SERVICES_PULL_TIMEOUT", 1800),
        recreate_timeout=positive_setting("GAK_SERVICES_RECREATE_TIMEOUT", 600),
        provider_timeout=positive_setting("GAK_SERVICES_PROVIDER_TIMEOUT", 120),
        hook_timeout=positive_setting("GAK_SERVICES_HOOK_TIMEOUT", 3600),
        probe_timeout=positive_setting("GAK_SERVICES_PROBE_TIMEOUT", 30),
        readiness_interval=float(positive_setting("GAK_SERVICES_READINESS_INTERVAL", 2)),
        settle_seconds=float(positive_setting("GAK_SERVICES_SETTLE_SECONDS", 3)),
        show_provider_errors=bool(os.environ.get("GAK_SERVICES_SHOW_PROVIDER_ERRORS")),
        show_hook_output=bool(os.environ.get("GAK_SERVICES_SHOW_HOOK_OUTPUT")),
    )
    probe = run(
        runtime.podman_argv("compose", "version"),
        timeout=runtime.provider_timeout,
        what="the Compose provider probe",
        env=env,
    )
    if probe.status != 0:
        raise Fatal(
            "no Compose provider answered; the host declares podman-compose in "
            "its Guix Home environment"
        )
    return runtime


# --- definition loading and schema validation -------------------------------


def parse_document(text: str, project: str) -> dict:
    """Load the provider's normalized output without echoing any of it."""
    try:
        document = yaml.safe_load(text)
    except yaml.MarkedYAMLError as error:
        where = ""
        if error.problem_mark is not None:
            where = (
                f" at line {error.problem_mark.line + 1}"
                f" column {error.problem_mark.column + 1}"
            )
        raise Fatal(
            f"the normalized definition of project {project} is not loadable{where}"
        ) from None
    except yaml.YAMLError:
        raise Fatal(
            f"the normalized definition of project {project} is not loadable"
        ) from None
    if not isinstance(document, dict):
        raise Fatal(f"the normalized definition of project {project} is not a mapping")
    return document


def read_services(document: dict, project: str) -> dict[str, str]:
    services = document.get("services")
    if not isinstance(services, dict) or not services:
        raise Fatal(f"project {project} declares no active service")
    images: dict[str, str] = {}
    for name, definition in services.items():
        if not isinstance(name, str) or not name:
            raise Fatal(f"project {project} declares a service without a usable name")
        if not isinstance(definition, dict):
            raise Fatal(f"project {project} service {name} is not a mapping")
        if "build" in definition:
            raise Fatal(
                f"project {project} service {name} is built locally; "
                "this updater does not execute Compose builds"
            )
        image = definition.get("image")
        if not isinstance(image, str) or not image.strip():
            raise Fatal(f"project {project} service {name} names no image")
        images[name] = image
    return images


def check_argument(value: object, project: str, key: str, position: int) -> str:
    where = f"project {project} {EXTENSION_KEY} {key} argument {position}"
    if isinstance(value, bool) or not isinstance(value, str):
        raise Fatal(f"{where} is not a string")
    if not value:
        raise Fatal(f"{where} is empty")
    if not value.isprintable():
        raise Fatal(f"{where} holds a control character or line break")
    return value


def check_seconds(value: object, project: str, key: str) -> int:
    where = f"project {project} {EXTENSION_KEY} {key}"
    if isinstance(value, bool) or not isinstance(value, int):
        raise Fatal(f"{where} is not a whole number of seconds")
    if not 1 <= value <= 3600:
        raise Fatal(f"{where} must be 1..3600 seconds")
    return value


def check_hook(argv: list[str], project: str, key: str) -> list[str]:
    command = argv[0]
    where = f"project {project} {EXTENSION_KEY} {key}"
    if not command.startswith("/"):
        raise Fatal(f"{where} must name its command by absolute path")
    path = Path(command)
    if not path.is_file():
        raise Fatal(f"{where} command does not exist: {command}")
    if not os.access(path, os.X_OK):
        raise Fatal(f"{where} command is not executable: {command}")
    return argv


@dataclass
class Extension:
    before_update: list[str] | None = None
    before_update_timeout: int = 0
    readiness: list[str] | None = None
    readiness_timeout: int = 0


def read_extension(document: dict, project: str) -> Extension:
    """Validate the optional update policy against a closed schema.

    Absent is fine; present and not a mapping is an error rather than something
    to step over, because a policy the operator wrote and this program ignored
    is the failure that matters here.
    """
    if EXTENSION_KEY not in document:
        return Extension()
    raw = document[EXTENSION_KEY]
    if not isinstance(raw, dict):
        raise Fatal(f"project {project} {EXTENSION_KEY} is not a mapping")

    known = {"before-update", "before-update-timeout", "readiness", "readiness-timeout"}
    unknown = sorted(str(key) for key in raw if key not in known)
    if unknown:
        raise Fatal(
            f"project {project} {EXTENSION_KEY} has unknown keys: {', '.join(unknown)}"
        )

    extension = Extension()
    for key in ("before-update", "readiness"):
        if key not in raw:
            continue
        value = raw[key]
        if not isinstance(value, list) or not value:
            raise Fatal(
                f"project {project} {EXTENSION_KEY} {key} is not a non-empty list of arguments"
            )
        argv = [
            check_argument(item, project, key, position)
            for position, item in enumerate(value, start=1)
        ]
        check_hook(argv, project, key)
        if key == "before-update":
            extension.before_update = argv
        else:
            extension.readiness = argv

    for key in ("before-update-timeout", "readiness-timeout"):
        if key not in raw:
            continue
        seconds = check_seconds(raw[key], project, key)
        if key == "before-update-timeout":
            extension.before_update_timeout = seconds
        else:
            extension.readiness_timeout = seconds

    if extension.before_update_timeout and extension.before_update is None:
        raise Fatal(
            f"project {project} {EXTENSION_KEY} before-update-timeout has no before-update command"
        )
    return extension


# --- projects ---------------------------------------------------------------


@dataclass
class Project:
    name: str
    directory: Path
    root: Path = field(default_factory=Path)
    images: dict[str, str] = field(default_factory=dict)
    extension: Extension = field(default_factory=Extension)
    state: str = "unknown"
    running_ids: dict[str, str] = field(default_factory=dict)
    initial_ids: dict[str, str] = field(default_factory=dict)
    planned_ids: dict[str, str] = field(default_factory=dict)
    reference_ids: dict[str, str] = field(default_factory=dict)
    outcome: str = ""
    definition_digest: str = ""

    @property
    def services(self) -> list[str]:
        return list(self.images)


def discover(services_root: Path) -> list[Project]:
    if not services_root.is_dir():
        raise Fatal(f"services root does not exist: {services_root}")
    projects = [
        Project(name=entry.name, directory=entry)
        for entry in sorted(services_root.iterdir())
        if entry.is_dir() and (entry / COMPOSE_BASENAME).is_file()
    ]
    if not projects:
        raise Fatal(f"no Compose project was found under {services_root}")
    return projects


def compose(
    runtime: Runtime, project: Project, *arguments: str, timeout: int, what: str,
    override: Path | None = None,
) -> Result:
    files = ["-f", COMPOSE_BASENAME]
    if override is not None:
        files.extend(("-f", str(override)))
    return run(
        runtime.podman_argv("compose", *files, *arguments),
        timeout=timeout,
        what=what,
        cwd=project.directory,
        env=runtime.env,
    )


def provider_detail(runtime: Runtime, result: Result) -> str:
    """Never repeat provider output by default; it quotes the definition."""
    if runtime.show_provider_errors and result.stderr.strip():
        return f"\nprovider output follows because GAK_SERVICES_SHOW_PROVIDER_ERRORS is set:\n{result.stderr.rstrip()}"
    return (
        " (set GAK_SERVICES_SHOW_PROVIDER_ERRORS=1 to see the provider's own "
        "message, which quotes the definition and may expose its environment)"
    )


def load_project(runtime: Runtime, project: Project) -> None:
    project.root = project.directory.resolve()
    result = compose(
        runtime,
        project,
        "config",
        timeout=runtime.provider_timeout,
        what=f"reading the definition of project {project.name}",
    )
    if result.status != 0:
        raise Fatal(
            f"the Compose provider rejected the definition of project {project.name}"
            + provider_detail(runtime, result)
        )
    document = parse_document(result.stdout, project.name)
    project.definition_digest = hashlib.sha256(result.stdout.encode()).hexdigest()
    project.images = read_services(document, project.name)
    project.extension = read_extension(document, project.name)
    inspect_project(runtime, project)
    project.initial_ids = dict(project.running_ids)


def time_budget(runtime: Runtime, deadline: float | None) -> float:
    remaining = runtime.inspect_timeout if deadline is None else deadline - time.monotonic()
    if remaining <= 0:
        raise ProjectFailure("readiness deadline expired")
    return min(runtime.inspect_timeout, remaining)


def container_names(runtime: Runtime, project: Project, deadline: float | None = None) -> list[str]:
    result = run(
        runtime.podman_argv(
            "ps", "-a", "--filter", f"label={WORKING_DIR_LABEL}={project.root}",
            "--format", "{{.Names}}",
        ),
        timeout=time_budget(runtime, deadline),
        what=f"listing the containers of project {project.name}",
        env=runtime.env,
    )
    if result.status != 0:
        raise Fatal(f"could not list the containers of project {project.name}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


@dataclass
class Observation:
    running_ids: dict[str, str]
    restarts: dict[str, int]
    state: str


def observe(runtime: Runtime, project: Project, deadline: float | None = None) -> Observation:
    """Read which declared services are running, on which image.

    Identity is the realpath of the project directory matched against the
    provider's working_dir label, so a container that merely shares a name is
    never taken for this project.
    """
    names = container_names(runtime, project, deadline)
    running_ids: dict[str, str] = {}
    restarts: dict[str, int] = {}
    if names:
        result = run(
            runtime.podman_argv("inspect", "--type", "container", "--format", INSPECT_FORMAT, *names),
            timeout=time_budget(runtime, deadline),
            what=f"inspecting the containers of project {project.name}",
            env=runtime.env,
        )
        if result.status != 0:
            raise Fatal(f"could not inspect the containers of project {project.name}")
        try:
            containers = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
        except json.JSONDecodeError:
            raise Fatal(
                f"could not read the container state of project {project.name}"
            ) from None
        for container in containers:
            if container.get("status") != "running":
                continue
            service = container.get("service")
            if not service:
                raise Fatal(
                    f"project {project.name} has a running container with no Compose service label"
                )
            if service in running_ids:
                raise Fatal(
                    f"project {project.name} runs more than one container for service {service}"
                )
            running_ids[service] = normalize_id(str(container.get("image", "")))
            restarts[service] = int(container.get("restarts", 0))

    extra = sorted(set(running_ids) - set(project.images))
    if extra:
        raise Fatal(
            f"project {project.name} runs containers for services it does not "
            f"declare: {', '.join(extra)}"
        )
    if not running_ids:
        state = "stopped"
    elif set(running_ids) == set(project.images):
        state = "running"
    else:
        state = "partial"
    return Observation(running_ids, restarts, state)


def inspect_project(runtime: Runtime, project: Project) -> None:
    observation = observe(runtime, project)
    project.state = observation.state
    project.running_ids = observation.running_ids


def resolve_images(runtime: Runtime, project: Project) -> dict[str, str]:
    """What each declared image reference points at locally, right now."""
    resolved: dict[str, str] = {}
    for service, reference in project.images.items():
        result = run(
            runtime.podman_argv("image", "inspect", "--format", "{{.Id}}", reference),
            timeout=runtime.inspect_timeout,
            what=f"resolving the image of project {project.name}",
            env=runtime.env,
        )
        if result.status != 0:
            raise ProjectFailure(
                f"project {project.name} has no local image for service {service}"
            )
        identity = normalize_id(result.stdout.strip())
        if len(identity) < 12 or any(character not in "0123456789abcdef" for character in identity):
            raise ProjectFailure(
                f"project {project.name} resolved an unusable image identity for service {service}"
            )
        resolved[service] = identity
    return resolved


# --- hooks ------------------------------------------------------------------


def hook_environment(runtime: Runtime, project: Project) -> dict[str, str]:
    environment = dict(runtime.env)
    environment["GAK_SERVICES_PROJECT"] = project.name
    environment["GAK_SERVICES_PROJECT_DIR"] = str(project.root)
    return environment


def run_hook(
    runtime: Runtime, project: Project, argv: list[str], *, timeout: float, label: str
) -> Result:
    return run(
        argv,
        timeout=timeout,
        what=f"the {label} command of project {project.name}",
        cwd=project.directory,
        env=hook_environment(runtime, project),
        capture=not runtime.show_hook_output,
    )


# --- readiness --------------------------------------------------------------


def readiness_bound(runtime: Runtime, project: Project, fallback: int) -> int:
    return project.extension.readiness_timeout or fallback


def await_readiness(
    runtime: Runtime, project: Project, *, timeout: int, interval: float, settle: float
) -> None:
    """Bounded readiness, measured against a monotonic deadline.

    Container health status is deliberately not consulted: Podman schedules
    healthchecks through systemd timers, which this host does not run, so a
    healthcheck-bearing image reports `starting` indefinitely. Without a
    declared readiness command the assurance is that every declared service has
    a container running the planned image and holding still across the settle
    period. That is process liveness on the intended image, not application
    readiness; a project that needs the stronger statement declares its own
    readiness command.
    """
    deadline = time.monotonic() + timeout
    expected = set(project.images)

    while True:
        observation = observe(runtime, project, deadline)
        if set(observation.running_ids) == expected:
            break
        if time.monotonic() >= deadline:
            raise ProjectFailure(
                f"project {project.name} did not bring every service up within {timeout}s"
            )
        time.sleep(min(interval, max(0, deadline - time.monotonic())))

    started = observation.restarts
    time.sleep(min(settle, max(0, deadline - time.monotonic())))
    settled = observe(runtime, project, deadline)
    if set(settled.running_ids) != expected or settled.restarts != started:
        raise ProjectFailure(
            f"project {project.name} did not hold still after recreation"
        )

    # A recreation that quietly kept the old container is not an update.
    drifted = sorted(
        service
        for service, identity in settled.running_ids.items()
        if identity != project.planned_ids.get(service)
    )
    if drifted:
        raise ProjectFailure(
            f"project {project.name} is running images the plan did not choose "
            f"for: {', '.join(drifted)}"
        )
    project.running_ids = settled.running_ids

    if project.extension.readiness is None:
        return
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ProjectFailure(
                f"project {project.name} was not ready within {timeout}s"
            )
        bound = min(remaining, float(runtime.probe_timeout))
        try:
            result = run_hook(
                runtime, project, project.extension.readiness,
                timeout=bound, label="readiness",
            )
        except Timeout:
            result = Result(1, "", "")
        if result.status == 0:
            final = observe(runtime, project, deadline)
            if final.running_ids != project.planned_ids or final.restarts != settled.restarts:
                raise ProjectFailure(f"project {project.name} changed while checking readiness")
            return
        if time.monotonic() >= deadline:
            raise ProjectFailure(
                f"project {project.name} was not ready within {timeout}s"
            )
        time.sleep(min(interval, max(0, deadline - time.monotonic())))


# --- drift ------------------------------------------------------------------


def confirm_runtime(runtime: Runtime, project: Project, moment: str) -> None:
    observation = observe(runtime, project)
    if observation.state != project.state or observation.running_ids != project.running_ids:
        raise ProjectFailure(
            f"project {project.name} changed its running state {moment}"
        )


def confirm_planned_images(runtime: Runtime, project: Project, moment: str) -> None:
    if resolve_images(runtime, project) != project.planned_ids:
        raise ProjectFailure(
            f"project {project.name} changed what its image references resolve to {moment}"
        )


# --- reporting --------------------------------------------------------------


def confirm_definition(runtime: Runtime, project: Project) -> None:
    result = compose(runtime, project, "config", timeout=runtime.provider_timeout,
                     what=f"rechecking the definition of project {project.name}")
    if result.status or hashlib.sha256(result.stdout.encode()).hexdigest() != project.definition_digest:
        raise ProjectFailure(f"project {project.name} changed its definition during the update")


def print_plan(projects: list[Project], services_root: Path) -> None:
    note(f"services root: {services_root}")
    for project in projects:
        note(f"  {project.name} [{project.state}] services: {' '.join(project.services)}")
        if project.extension.before_update:
            note(f"    before-update: {project.extension.before_update[0]}")
        if project.extension.readiness:
            bound = project.extension.readiness_timeout
            suffix = f" (timeout {bound}s)" if bound else ""
            note(f"    readiness: {project.extension.readiness[0]}{suffix}")


def print_summary(selected: list[Project]) -> None:
    note("--- summary ---")
    for project in selected:
        note(f"  {project.name}: {project.outcome or 'not reached'}")
        if project.outcome in ("updated", "unchanged", "would update"):
            for service in project.services:
                before = project.initial_ids.get(service, "")
                after = project.planned_ids.get(service, "")
                if before and after:
                    note(f"    {service}: {short_id(before)} -> {short_id(after)}")
                elif before:
                    note(f"    {service}: running {short_id(before)}")


# --- the update ------------------------------------------------------------


@dataclass
class Options:
    names: list[str]
    every: bool
    dry_run: bool
    force: bool
    timeout: int
    prepared: dict[str, str]
    from_stopped: bool


def select(runtime: Runtime, options: Options, services_root: Path) -> tuple[list[Project], list[Project]]:
    """Return the projects to load and the subset selected for update.

    With explicit names only those projects are loaded, so an unrelated project
    in a broken state does not stand in the way of a targeted repair. With
    --all every discovered project is loaded and a partially running one stops
    the run before any mutation.
    """
    discovered = {project.name: project for project in discover(services_root)}

    if options.every:
        loaded = list(discovered.values())
        for project in loaded:
            load_project(runtime, project)
        partial = [project.name for project in loaded if project.state == "partial"]
        if partial:
            raise Fatal(
                f"repair partially running projects before any update: {', '.join(partial)}"
            )
        selected = []
        for project in loaded:
            if project.state == "running":
                selected.append(project)
            else:
                warn(f"leaving the project that is not running: {project.name}")
        if not selected:
            raise Fatal("no running project is eligible for an update")
        return loaded, selected

    wanted: list[str] = []
    for name in options.names:
        if name not in wanted:
            wanted.append(name)
    loaded = []
    for name in wanted:
        project = discovered.get(name)
        if project is None:
            raise Fatal(f"no Compose project named {name} under {services_root}")
        load_project(runtime, project)
        loaded.append(project)
    for project in loaded:
        if project.state == "partial":
            raise Fatal(
                f"project {project.name} is only partially running; repair it before updating it"
            )
        if project.state != "running" and not (options.from_stopped and project.state == "stopped"):
            raise Fatal(
                f"project {project.name} is not running; start it deliberately before updating it"
            )
    return loaded, loaded


def update(runtime: Runtime, options: Options, services_root: Path, runtime_dir: Path) -> int:
    loaded, selected = select(runtime, options, services_root)
    if options.prepared:
        if len(selected) != 1:
            raise Usage("prepared images require exactly one named project")
        unknown = sorted(set(options.prepared) - set(selected[0].images))
        if unknown:
            raise Usage(f"project {selected[0].name} has no services: {', '.join(unknown)}")
        selected[0].reference_ids = resolve_images(runtime, selected[0])
        for service, identity in options.prepared.items():
            result = run(runtime.podman_argv("image", "inspect", "--format", "{{.Id}}", identity),
                         timeout=runtime.inspect_timeout, what=f"checking prepared image for {service}",
                         env=runtime.env)
            if result.status or normalize_id(result.stdout.strip()) != identity:
                raise Fatal(f"prepared image for {service} is absent or changed locally")

    if options.dry_run:
        print_plan(loaded, services_root)
        for project in selected:
            project.outcome = "would update"
        note("dry run: no image was pulled, no hook ran and no container was recreated")
        print_summary(selected)
        return 0

    if not options.prepared:
        for project in selected:
            result = compose(
                runtime, project, "pull",
                timeout=runtime.pull_timeout,
                what=f"pulling project {project.name}",
            )
            if result.status != 0:
                raise Fatal(
                    f"the pull failed for project {project.name}; nothing was recreated"
                    + provider_detail(runtime, result)
                )

    status = 0
    for position, project in enumerate(selected):
        try:
            project.planned_ids = resolve_images(runtime, project)
            project.planned_ids.update(options.prepared)
            if not options.force and project.planned_ids == project.running_ids:
                confirm_runtime(runtime, project, "while images were pulled")
                project.outcome = "unchanged"
                continue
            recreate(runtime, project, options, runtime_dir)
            project.outcome = "updated"
        except (ProjectFailure, Timeout, Fatal) as failure:
            project.outcome = f"failed: {failure}"
            status = 1
            for remaining in selected[position + 1:]:
                remaining.outcome = "skipped after an earlier failure"
            break

    print_summary(selected)
    if status:
        warn("the update stopped on a failing project; the previous images were kept")
    return status


def recreate(runtime: Runtime, project: Project, options: Options, runtime_dir: Path) -> None:
    confirm_runtime(runtime, project, "between planning and recreation")

    if project.extension.before_update is not None:
        bound = project.extension.before_update_timeout or runtime.hook_timeout
        result = run_hook(
            runtime, project, project.extension.before_update,
            timeout=bound, label="before-update",
        )
        if result.status != 0:
            raise ProjectFailure("the before-update hook did not succeed")
        # The gate may legitimately touch the project; nothing may be recreated
        # on a picture taken before it ran.
        confirm_runtime(runtime, project, "while the before-update hook ran")
        if options.prepared:
            if resolve_images(runtime, project) != project.reference_ids:
                raise ProjectFailure(f"project {project.name} changed its image references while the before-update hook ran")
        else:
            confirm_planned_images(runtime, project, "while the before-update hook ran")

    confirm_definition(runtime, project)
    if options.prepared:
        if resolve_images(runtime, project) != project.reference_ids:
            raise ProjectFailure(f"project {project.name} changed its image references before recreation")
        for service in options.prepared:
            old = project.reference_ids[service]
            pin = "localhost/gak-services-previous:" + hashlib.sha256(
                f"{project.root}:{service}".encode()).hexdigest()[:24]
            result = run(runtime.podman_argv("tag", old, pin),
                         timeout=runtime.inspect_timeout, what=f"retaining the image for {service}",
                         env=runtime.env)
            if result.status:
                raise ProjectFailure(f"could not retain the previous image for {service}")
        with tempfile.TemporaryDirectory(prefix="prepared-", dir=runtime_dir) as temporary:
            override = Path(temporary) / "override.yaml"
            override.write_text(json.dumps({"services": {
                service: {"image": f"sha256:{identity}"}
                for service, identity in project.planned_ids.items()
            }}))
            confirm_definition(runtime, project)
            if resolve_images(runtime, project) != project.reference_ids:
                raise ProjectFailure(f"project {project.name} changed its image references before recreation")
            result = compose(
                runtime, project, "up", "-d", "--force-recreate", "--pull", "never",
                timeout=runtime.recreate_timeout, what=f"recreating project {project.name}",
                override=override,
            )
            if result.status != 0:
                raise ProjectFailure("recreation failed" + provider_detail(runtime, result))
            await_readiness(
                runtime, project,
                timeout=readiness_bound(runtime, project, options.timeout),
                interval=runtime.readiness_interval,
                settle=runtime.settle_seconds,
            )
        if resolve_images(runtime, project) != project.reference_ids:
            raise ProjectFailure(f"project {project.name} changed its image references during recreation")
        for service, identity in options.prepared.items():
            result = run(runtime.podman_argv("tag", identity, project.images[service]),
                         timeout=runtime.inspect_timeout, what=f"accepting the image for {service}",
                         env=runtime.env)
            if result.status:
                raise ProjectFailure(f"could not accept the prepared image for {service}")
        confirm_planned_images(runtime, project, "after readiness")
    else:
        confirm_planned_images(runtime, project, "before recreation")
        result = compose(
            runtime, project, "up", "-d", "--force-recreate", "--pull", "never",
            timeout=runtime.recreate_timeout, what=f"recreating project {project.name}",
        )
        if result.status != 0:
            raise ProjectFailure("recreation failed" + provider_detail(runtime, result))
        confirm_planned_images(runtime, project, "during recreation")
        await_readiness(
            runtime, project,
            timeout=readiness_bound(runtime, project, options.timeout),
            interval=runtime.readiness_interval,
            settle=runtime.settle_seconds,
        )
        confirm_planned_images(runtime, project, "during readiness")


def show(runtime: Runtime, services_root: Path) -> int:
    projects = discover(services_root)
    for project in projects:
        load_project(runtime, project)
    print_plan(projects, services_root)
    return 0


# --- the lock ---------------------------------------------------------------


def acquire_lock(runtime_dir: Path) -> int:
    """Hold the update lock for this process only.

    Python marks its descriptors close-on-exec, so no child and no detached
    Podman descendant inherits the lock; it is released when this process ends,
    which is after every child it started has been stopped.
    """
    runtime_dir.mkdir(parents=True, exist_ok=True)
    runtime_dir.chmod(0o700)
    path = Path(setting("GAK_SERVICES_LOCK_FILE", str(runtime_dir / "update.lock")))
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_CLOEXEC, 0o600)
    os.set_inheritable(descriptor, False)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(descriptor)
        raise Fatal("another gak-services update is already running") from None
    return descriptor


# --- entry point ------------------------------------------------------------


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog=PROGRAM, add_help=True)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("list", help="show the discovered projects and their update policy")
    updater = commands.add_parser("update", help="update selected projects")
    updater.add_argument("names", nargs="*", metavar="NAME")
    updater.add_argument("--all", dest="every", action="store_true")
    updater.add_argument("--dry-run", dest="dry_run", action="store_true")
    updater.add_argument("--force", action="store_true")
    updater.add_argument("--prepared-image", action="append", default=[], metavar="SERVICE=IMAGE_ID")
    updater.add_argument("--from-stopped", action="store_true")
    updater.add_argument("--timeout", type=int, default=None)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    arguments = parse_arguments(argv)
    home = Path(os.environ["HOME"])
    services_root = Path(setting("GAK_COMPOSE_SERVICES_ROOT", str(home / "services")))
    runtime_dir = Path(
        setting(
            "GAK_SERVICES_RUNTIME_DIR",
            str(Path(os.environ.get("XDG_RUNTIME_DIR") or home / ".local/state") / "gak-services"),
        )
    )

    if arguments.command == "list":
        runtime = build_runtime()
        return show(runtime, services_root)

    if arguments.every and arguments.names:
        raise Usage("--all and explicit project names are mutually exclusive")
    if not arguments.every and not arguments.names:
        raise Usage("name at least one project or pass --all")
    if arguments.timeout is not None and arguments.timeout < 1:
        raise Usage("--timeout needs a positive number of seconds")
    prepared = {}
    for specification in arguments.prepared_image:
        service, separator, identity = specification.partition("=")
        identity = normalize_id(identity)
        if (not separator or not service or service in prepared or len(identity) < 12
                or any(character not in "0123456789abcdef" for character in identity)):
            raise Usage("--prepared-image requires a unique SERVICE=IMAGE_ID with a hexadecimal image ID")
        prepared[service] = identity
    if prepared and (arguments.every or len(arguments.names) != 1):
        raise Usage("prepared images require exactly one named project")
    if arguments.from_stopped and not prepared:
        raise Usage("--from-stopped requires a prepared image")

    options = Options(
        names=list(arguments.names),
        every=arguments.every,
        dry_run=arguments.dry_run,
        force=arguments.force,
        timeout=arguments.timeout or positive_setting("GAK_SERVICES_READINESS_TIMEOUT", 180),
        prepared=prepared,
        from_stopped=arguments.from_stopped,
    )

    runtime = build_runtime()
    descriptor = acquire_lock(runtime_dir)
    try:
        return update(runtime, options, services_root, runtime_dir)
    finally:
        # The lock outlives every child it started: nothing is released while a
        # hook or a Compose command is still being stopped.
        stop_live_processes()
        os.close(descriptor)


def interrupted(signum: int, _frame: object) -> None:
    stop_live_processes()
    warn(f"stopped on signal {signum}")
    raise SystemExit(1)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        raise SystemExit(main(sys.argv[1:]))
    except Usage as error:
        warn(str(error))
        raise SystemExit(2) from None
    except Fatal as error:
        warn(str(error))
        raise SystemExit(1) from None
    except Timeout as error:
        warn(str(error))
        raise SystemExit(1) from None
    finally:
        stop_live_processes()
