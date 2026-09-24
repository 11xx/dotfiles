#!/usr/bin/env python3
import errno
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager


HOME = Path("/home/aiagent")
HUB_HOME = Path("/var/lib/agentgit")
HUB_REPOS = ("gitolite-admin", "arc")
HUB_LOCK_DIRECTORY = Path("/var/lib/agentgit-lock")
HUB_LOCK = HUB_LOCK_DIRECTORY / "receive.lock"
RUNTIME = Path("/run/aiagent")
RESULT_ROOT = Path("/run/aiagent-backup")
STATE = Path("/var/lib/aiagent")
BACKUP_ROOT = Path("/marak/backups/aiagent")
REPOSITORY = BACKUP_ROOT / "restic"
PASSWORD = Path("/etc/aiagent/restic-password")
SERVICE = "aiagent-compose"
STOP_TIMEOUT = 2700
START_TIMEOUT = 180
HOME_START_TIMEOUT = 1800
RECOVERY_TIMEOUT = 2700
NOFOLLOW = os.O_NOFOLLOW | os.O_CLOEXEC
SIGNALS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)
_signal_depth = 0
_interrupted = None


class Busy(Exception):
    pass


class Interrupted(Exception):
    def __init__(self, signum):
        super().__init__(f"interrupted by signal {signum}")
        self.signum = signum


def handle_signal(signum, _frame):
    global _interrupted
    if _interrupted is None:
        _interrupted = signum


def check_interrupted():
    if _interrupted is not None:
        raise Interrupted(_interrupted)


@contextmanager
def signal_guard():
    global _signal_depth, _interrupted
    previous = None
    if _signal_depth == 0:
        _interrupted = None
        previous = {}
        try:
            for signum in SIGNALS:
                previous[signum] = signal.getsignal(signum)
                signal.signal(signum, handle_signal)
        except BaseException:
            for signum, handler in previous.items():
                signal.signal(signum, handler)
            raise
    _signal_depth += 1
    try:
        yield
    finally:
        _signal_depth -= 1
        if previous is not None:
            for signum, handler in previous.items():
                signal.signal(signum, handler)


def agent_account():
    return pwd.getpwnam("aiagent")


def hub_account():
    try:
        return pwd.getpwnam("agentgit")
    except KeyError:
        return None


@contextmanager
def hub_exclusion():
    account = hub_account()
    if account is None:
        yield
        return
    directory = HUB_LOCK_DIRECTORY.lstat()
    if (not stat.S_ISDIR(directory.st_mode) or directory.st_uid != 0
            or directory.st_gid != account.pw_gid
            or stat.S_IMODE(directory.st_mode) != 0o750):
        raise RuntimeError("unsafe Git hub lock directory")
    descriptor, metadata = secure_file(HUB_LOCK, os.O_RDWR, 0)
    try:
        if metadata.st_gid != account.pw_gid or stat.S_IMODE(metadata.st_mode) != 0o660:
            raise RuntimeError("unsafe Git hub lock file")
        deadline = time.monotonic() + 300
        while True:
            check_interrupted()
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise Busy("Git hub receive did not finish before backup deadline") from None
                time.sleep(0.2)
        yield
    finally:
        os.close(descriptor)


def root_directory(path, create=False):
    if create:
        try:
            path.mkdir(mode=0o700)
        except FileExistsError:
            pass
    metadata = path.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) != 0o700:
        raise RuntimeError(f"unsafe backup directory: {path}")


def secure_file(path, flags, owner=None):
    descriptor = os.open(path, flags | NOFOLLOW | os.O_NONBLOCK)
    metadata = os.fstat(descriptor)
    if not stat.S_ISREG(metadata.st_mode) or (owner is not None and metadata.st_uid != owner):
        os.close(descriptor)
        raise RuntimeError(f"unsafe backup file: {path}")
    return descriptor, metadata


def stop_process(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        process.poll()
        try:
            os.killpg(process.pid, 0)
        except ProcessLookupError:
            break
        time.sleep(0.05)
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        process.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait(timeout=5)


def run_process(arguments, *, check=False, timeout=None, env=None,
                stdin=None, stdout=None, stderr=None, capture_output=False, text=False,
                cwd=None,
                ignore_interrupt=False, user=None, group=None, extra_groups=None):
    if not ignore_interrupt:
        check_interrupted()
    process = subprocess.Popen(
        arguments, env=env, stdin=stdin,
        stdout=subprocess.PIPE if capture_output else stdout,
        stderr=subprocess.PIPE if capture_output else stderr,
        text=text, cwd=cwd, start_new_session=True, user=user, group=group,
        extra_groups=extra_groups,
    )
    deadline = None if timeout is None else time.monotonic() + timeout
    try:
        while True:
            if not ignore_interrupt:
                check_interrupted()
            remaining = None if deadline is None else deadline - time.monotonic()
            if remaining is not None and remaining <= 0:
                raise subprocess.TimeoutExpired(arguments, timeout)
            interval = 0.2 if remaining is None else min(0.2, remaining)
            try:
                output, errors = process.communicate(timeout=interval)
                break
            except subprocess.TimeoutExpired:
                continue
        if not ignore_interrupt:
            check_interrupted()
    except (Interrupted, subprocess.TimeoutExpired):
        stop_process(process)
        raise
    result = subprocess.CompletedProcess(arguments, process.returncode, output, errors)
    if check:
        result.check_returncode()
    return result


def command(*arguments, timeout=None, capture=False):
    return run_process(arguments, check=True, timeout=timeout,
                       capture_output=capture, text=capture)


def validate_password():
    metadata = PASSWORD.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise RuntimeError("backup password file must be root-owned mode 0600")


def digest_file(path):
    digest = hashlib.sha256()
    descriptor, _ = secure_file(path, os.O_RDONLY, 0)
    with os.fdopen(descriptor, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            check_interrupted()
            digest.update(chunk)
    return digest.hexdigest()


def hub_git(account, environment, arguments, **kwargs):
    return run_process(("git", *arguments), check=True, env=environment,
                       user=account.pw_uid, group=account.pw_gid,
                       extra_groups=[], **kwargs)


def hub_git_environment():
    return dict(os.environ, HOME=str(HUB_HOME),
                XDG_CONFIG_HOME=str(HUB_HOME / ".config"),
                GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null")


def hub_refs(account, environment, source, cwd=None):
    result = hub_git(account, environment,
                     ("-C", str(source), "for-each-ref",
                      "--format=%(objectname) %(refname)"),
                     capture_output=True, text=True, cwd=cwd)
    refs = {}
    for line in result.stdout.splitlines():
        oid, ref = line.split(" ", 1)
        refs[ref] = oid
    head = hub_git(account, environment,
                   ("-C", str(source), "symbolic-ref", "HEAD"),
                   capture_output=True, text=True, cwd=cwd).stdout.strip()
    return refs, head


def verify_bundles(directory, expected, admin_files, account):
    imports = Path(tempfile.mkdtemp(prefix="restore.", dir=HUB_LOCK_DIRECTORY))
    os.chown(imports, account.pw_uid, account.pw_gid)
    environment = hub_git_environment()
    try:
        for name, details in expected.items():
            destination = f"{name}.git"
            hub_git(account, environment, ("init", "--bare", "--quiet", destination),
                    cwd=imports)
            descriptor, _ = secure_file(directory / f"{name}.bundle", os.O_RDONLY, 0)
            try:
                received = hub_git(account, environment,
                                   ("-C", destination, "bundle", "unbundle", "-"),
                                   stdin=descriptor, cwd=imports,
                                   capture_output=True, text=True)
            finally:
                os.close(descriptor)
            advertised = {}
            for line in received.stdout.splitlines():
                oid, ref = line.split(" ", 1)
                if ref.startswith("refs/"):
                    advertised[ref] = oid
            if advertised != details["refs"]:
                raise RuntimeError(f"Git hub bundle refs differ: {name}")
            for ref, oid in details["refs"].items():
                hub_git(account, environment,
                        ("-C", destination, "update-ref", ref, oid), cwd=imports)
            hub_git(account, environment,
                    ("-C", destination, "symbolic-ref", "HEAD", details["head"]),
                    cwd=imports)
            hub_git(account, environment,
                    ("-C", destination, "fsck", "--full", "--strict", "--no-reflogs"),
                    cwd=imports, stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL)
            refs, head = hub_refs(account, environment, destination, cwd=imports)
            if refs != details["refs"] or head != details["head"]:
                raise RuntimeError(f"Git hub restored refs differ: {name}")
        checkout = imports / "admin-files"
        checkout.mkdir(mode=0o700)
        os.chown(checkout, account.pw_uid, account.pw_gid)
        hub_git(account, environment,
                (f"--git-dir={imports / 'gitolite-admin.git'}",
                 f"--work-tree={checkout}", "checkout", "-f", "HEAD", "--",
                 "conf", "keydir"), cwd=imports)
        restored_files = manifest(checkout, ("conf/gitolite.conf", "keydir"))
        if restored_files != admin_files:
            differing = sorted(name for name in set(restored_files) | set(admin_files)
                               if restored_files.get(name) != admin_files.get(name))
            raise RuntimeError(f"Git hub administrative policy or keys differ: {differing}")
    finally:
        shutil.rmtree(imports)


def hub_bundles():
    account = hub_account()
    if account is None:
        return None, None
    metadata = HUB_HOME.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != account.pw_uid or stat.S_IMODE(metadata.st_mode) != 0o750:
        raise RuntimeError("unsafe Git hub home")
    scratch = Path(tempfile.mkdtemp(prefix="hub-bundles.", dir=BACKUP_ROOT))
    expected = {}
    environment = hub_git_environment()
    try:
        admin_files = manifest(HUB_HOME / ".gitolite",
                               ("conf/gitolite.conf", "keydir"))
        for name in HUB_REPOS:
            source = HUB_HOME / "repositories" / f"{name}.git"
            try:
                repo = source.lstat()
            except FileNotFoundError:
                if name == "arc":
                    continue
                raise RuntimeError("Git hub administration repository is missing") from None
            if not stat.S_ISDIR(repo.st_mode) or repo.st_uid != account.pw_uid:
                raise RuntimeError("unsafe Git hub repository")
            refs, head = hub_refs(account, environment, source)
            if not refs:
                if name == "arc":
                    continue
                raise RuntimeError("Git hub administration repository is empty")
            destination = scratch / f"{name}.bundle"
            descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW, 0o600)
            try:
                hub_git(account, environment,
                        ("-C", str(source), "bundle", "create", "-", "--all"),
                        stdout=descriptor)
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
            expected[name] = {"digest": digest_file(destination),
                              "refs": refs, "head": head}
        verify_bundles(scratch, expected, admin_files, account)
        recorded = {"repos": expected, "admin_files": admin_files}
        manifest_file = scratch / "manifest.json"
        descriptor = os.open(manifest_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as output:
            json.dump(recorded, output, sort_keys=True)
            output.flush()
            os.fsync(output.fileno())
        return scratch, recorded
    except BaseException:
        shutil.rmtree(scratch)
        raise


def snapshot():
    validate_password()
    if run_process(("findmnt", "-n", "--mountpoint", str(HOME)),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
        raise RuntimeError("agent home is not mounted")
    root_directory(BACKUP_ROOT, create=True)
    root_directory(REPOSITORY, create=True)
    environment = dict(os.environ, RESTIC_REPOSITORY=str(REPOSITORY),
                       RESTIC_PASSWORD_FILE=str(PASSWORD))

    def restic(*arguments, quiet=True):
        argv = ["restic", *arguments]
        if quiet:
            argv.insert(1, "--quiet")
        run_process(argv, check=True, env=environment)

    with hub_exclusion():
        bundles, expected = hub_bundles()
        try:
            if not (REPOSITORY / "config").is_file():
                restic("init")
            sources = [str(HOME / "workspaces"), str(HOME / "container-home")]
            if bundles is not None:
                sources.append(str(bundles))
            restic("backup", "--host", "gak", "--tag", "aiagent", *sources)
        finally:
            if bundles is not None:
                shutil.rmtree(bundles)
    restic("forget", "--host", "gak", "--tag", "aiagent",
           "--keep-daily", "7", "--keep-weekly", "5", "--keep-monthly", "12", "--prune")
    restic("check")
    return environment, bundles, expected


def process_identity(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    except FileNotFoundError:
        return None
    if fields[0] in ("Z", "X"):
        return None
    return fields[19]


ROOTLESSPORT = Path("/run/current-system/profile/libexec/podman/rootlessport")
ROOTLESSPORT_CGROUP = "0::/aiagent/delegated/service/cli/runtime"


def persistent_port_helper(entry):
    try:
        if ROOTLESSPORT_CGROUP not in (entry / "cgroup").read_text().splitlines():
            return False
        if (entry / "cmdline").read_bytes().split(b"\0", 1)[0] not in (
            b"rootlessport", b"rootlessport-child"
        ):
            return False
        return (entry / "exe").samefile(ROOTLESSPORT)
    except OSError:
        return False


def process_session_active(pid, started):
    identity = process_identity(pid)
    if identity is not None:
        return identity == started
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal():
            continue
        try:
            fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
        except OSError:
            continue
        if (fields[0] not in ("Z", "X") and fields[3] == str(pid)
                and not persistent_port_helper(entry)):
            return True
    return False


def active_operation():
    try:
        descriptor, _ = secure_file(RUNTIME / "aiagent.active", os.O_RDONLY, agent_account().pw_uid)
    except FileNotFoundError:
        return False
    try:
        payload = os.read(descriptor, 4097)
    finally:
        os.close(descriptor)
    if len(payload) > 4096:
        raise Busy("agent operation record is too large")
    try:
        record = json.loads(payload)
        pid, started = record["pid"], record["start"]
        if not isinstance(pid, int) or pid < 1 or not isinstance(started, str):
            raise ValueError()
    except (ValueError, KeyError, TypeError):
        raise Busy("agent operation record is invalid") from None
    return process_session_active(pid, started)


def operation_lock():
    descriptor, _ = secure_file(RUNTIME / "aiagent.lock", os.O_RDONLY, agent_account().pw_uid)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Busy("an agent operation holds the lock") from None
        if active_operation():
            raise Busy("an agent operation worker is still running")
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise


def read_request():
    path = RUNTIME / "backup-request"
    try:
        descriptor, metadata = secure_file(path, os.O_RDONLY, agent_account().pw_uid)
    except FileNotFoundError:
        return None
    try:
        if stat.S_IMODE(metadata.st_mode) != 0o600:
            raise RuntimeError("unsafe backup request mode")
        payload = os.read(descriptor, 129)
        if len(payload) > 128:
            raise RuntimeError("backup request is too large")
    finally:
        os.close(descriptor)
    try:
        nonce = payload.decode("ascii").strip()
    except UnicodeDecodeError:
        raise RuntimeError("invalid backup request") from None
    if re.fullmatch(r"[0-9]+-[0-9]+", nonce) is None:
        raise RuntimeError("invalid backup request")
    return nonce, (metadata.st_dev, metadata.st_ino)


def publish_result(nonce, outcome):
    account = agent_account()
    for _ in range(10):
        temporary = RESULT_ROOT / f"result.{secrets.token_hex(12)}"
        try:
            descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | NOFOLLOW, 0o600)
            break
        except FileExistsError:
            continue
    else:
        raise RuntimeError("cannot reserve backup result")
    try:
        payload = memoryview(f"{outcome} {nonce}\n".encode())
        while payload:
            payload = payload[os.write(descriptor, payload):]
        os.fchown(descriptor, account.pw_uid, account.pw_gid)
        os.fsync(descriptor)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    finally:
        os.close(descriptor)
    try:
        os.replace(temporary, RUNTIME / "backup-result")
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise


def request():
    received = read_request()
    if received is None:
        return
    nonce, identity = received
    failure = None
    try:
        snapshot()
    except Exception as error:
        failure = error
    publish_result(nonce, "failed" if failure else "ok")
    try:
        current = (RUNTIME / "backup-request").lstat()
        if (current.st_dev, current.st_ino) == identity:
            (RUNTIME / "backup-request").unlink()
    except FileNotFoundError:
        pass
    if failure:
        raise failure


def recover_service():
    deadline = time.monotonic() + RECOVERY_TIMEOUT

    def bound(limit):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError("agent Compose recovery deadline expired")
        return min(limit, remaining)

    def start(service, limit):
        for attempt in range(2):
            try:
                started = run_process(("herd", "start", service), timeout=bound(limit),
                                      ignore_interrupt=True)
                status = started.returncode
            except subprocess.TimeoutExpired:
                status = 124
            if status == 0:
                return
            if attempt == 0:
                try:
                    run_process(("herd", "enable", service), timeout=bound(START_TIMEOUT),
                                ignore_interrupt=True)
                except subprocess.TimeoutExpired:
                    pass
        raise RuntimeError(f"agent service did not restart: {service}")

    def mounted():
        return run_process(("findmnt", "-n", "--mountpoint", str(HOME)),
                           timeout=bound(30), stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, ignore_interrupt=True).returncode == 0

    if not mounted():
        start("aiagent-home", HOME_START_TIMEOUT)
        if not mounted():
            raise RuntimeError("agent home did not remount")
    try:
        start(SERVICE, START_TIMEOUT)
    except RuntimeError:
        start("aiagent-home", HOME_START_TIMEOUT)
        if not mounted():
            raise RuntimeError("agent home did not remount") from None
        start(SERVICE, START_TIMEOUT)


def quiesced(action):
    with signal_guard():
        try:
            check_interrupted()
            command("herd", "stop", SERVICE, timeout=STOP_TIMEOUT)
            check_interrupted()
            action()
            check_interrupted()
        finally:
            recover_service()
        check_interrupted()


def manifest(root, names=("workspaces", "container-home")):
    entries = {}

    def visit(path):
        check_interrupted()
        metadata = path.lstat()
        relative = str(path.relative_to(root))
        if stat.S_ISLNK(metadata.st_mode):
            entries[relative] = ("link", os.readlink(path))
        elif stat.S_ISDIR(metadata.st_mode):
            entries[relative] = ("directory",)
            for child in sorted(path.iterdir()):
                visit(child)
        elif stat.S_ISREG(metadata.st_mode):
            digest = hashlib.sha256()
            descriptor, _ = secure_file(path, os.O_RDONLY)
            with os.fdopen(descriptor, "rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    check_interrupted()
                    digest.update(chunk)
            entries[relative] = ("file", digest.hexdigest())
        else:
            entries[relative] = ("special", stat.S_IFMT(metadata.st_mode))

    for name in names:
        visit(root / name)
    return entries


def restore_check():
    environment, bundles, expected = snapshot()
    scratch = Path(tempfile.mkdtemp(prefix="restore-check.", dir=BACKUP_ROOT))
    try:
        run_process(("restic", "--quiet", "restore", "latest", "--host", "gak",
                     "--tag", "aiagent", "--target", str(scratch)),
                    check=True, env=environment)
        restored = scratch / HOME.relative_to("/")
        if manifest(HOME) != manifest(restored):
            raise RuntimeError("agent restore checksums or paths differ")
        print("agent restore checksums match")
        if bundles is not None:
            restored_bundles = scratch / bundles.relative_to("/")
            names = {f"{name}.bundle" for name in expected["repos"]}
            if {path.name for path in restored_bundles.iterdir()} != names | {"manifest.json"}:
                raise RuntimeError("Git hub restore bundle set differs")
            descriptor, _ = secure_file(restored_bundles / "manifest.json", os.O_RDONLY, 0)
            with os.fdopen(descriptor) as source:
                recorded = json.load(source)
            if recorded != json.loads(json.dumps(expected)):
                raise RuntimeError("Git hub restore manifest differs")
            for name, details in expected["repos"].items():
                if digest_file(restored_bundles / f"{name}.bundle") != details["digest"]:
                    raise RuntimeError("Git hub restore bundle checksum differs")
            verify_bundles(restored_bundles, expected["repos"],
                           expected["admin_files"], hub_account())
            print("Git hub restored objects, refs, policy and keys match")
    finally:
        shutil.rmtree(scratch)


def run_operation(operation):
    if os.geteuid() != 0:
        raise RuntimeError("agent backup requires root")
    os.environ["PATH"] = "/run/current-system/profile/bin:/run/privileged/bin:/usr/bin:/bin"
    root_directory(STATE)
    root_directory(RESULT_ROOT, create=True)
    descriptor = os.open(STATE / "backup.lock", os.O_RDWR | os.O_CREAT | NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Busy("another backup is running") from None
        if operation == "request":
            request()
        elif operation in ("daily", "restore-check"):
            validate_password()
            operation_descriptor = operation_lock()
            try:
                quiesced(snapshot if operation == "daily" else restore_check)
            finally:
                os.close(operation_descriptor)
        else:
            raise RuntimeError("usage: backup.py {request|daily|restore-check}")
    finally:
        os.close(descriptor)


def main(operation):
    with signal_guard():
        run_operation(operation)
        check_interrupted()


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) == 2 else "")
    except Busy as error:
        print(f"agent backup: {error}", file=sys.stderr)
        sys.exit(75)
    except Interrupted as error:
        print(f"agent backup: {error}", file=sys.stderr)
        sys.exit(128 + error.signum)
    except (OSError, RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"agent backup: {error}", file=sys.stderr)
        sys.exit(1)
