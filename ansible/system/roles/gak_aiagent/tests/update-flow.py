#!/usr/bin/env python3
"""Exercise candidate isolation and the snapshot boundary of aiagent update."""

import contextlib
import importlib.machinery
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time
from unittest import mock


ROLE = Path(__file__).resolve().parents[1]
SOURCE = ROLE / "files/aiagent-update"
STOP_SOURCE = ROLE / "files/aiagent-stop-outcome"
READINESS = ROLE / "files/image/bin/aiagent-readiness"
OLD = "a" * 64
NEW = "e" * 64
PODMAN = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["AIAGENT_UPDATE_TEST_ROOT"])
args = sys.argv[1:]
mode = os.environ.get("STOP_MODE", "graceful")
with (root / "calls").open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["image", "inspect"]:
    if args[-1] == "localhost/aiagent-fedora:44-v1":
        print("%s" if not (root / "accepted").exists() else "%s")
    elif args[-1].startswith("localhost/gak-services-previous:"):
        assert (root / "pin-present").exists()
        print("%s")
    else:
        print("%s")
elif args[:2] == ["container", "exists"]:
    if mode == "absent":
        sys.exit(1)
elif args[0] == "inspect":
    identity = "d" * 64 if mode == "replacement" and args[-1] == "aiagent" and (root / "stopped").exists() else "c" * 64
    stopped = (root / "stopped").exists()
    code = 124 if mode == "forced" and stopped else 0
    if mode == "historical" and stopped:
        code = 124
    print(f"{identity}|{'false' if stopped else 'true'}|{'exited' if stopped else 'running'}|{code}")
elif args[0] == "build":
    print("build progress from podman")
    print("Fedora 44 - Updates: repository metadata", file=sys.stderr)
    print("[1/117] Installing nodejs", file=sys.stderr)
    if os.environ.get("FAIL_PHASE") == "build-large":
        print("early build detail that must be truncated")
        print("x" * 200000)
        print("final build failure detail")
        sys.exit(37)
    if os.environ.get("FAIL_PHASE") == "build":
        print("build failure stderr detail", file=sys.stderr)
        print("build failure detail from podman")
        sys.exit(37)
elif args[0] == "run":
    assert "--network" in args and args[args.index("--network") + 1] == "none"
    assert not any(arg in ("-v", "--volume", "--mount") for arg in args)
    assert args[-2:] == ["/usr/local/bin/aiagent-readiness", "--candidate"]
    import subprocess
    sys.exit(subprocess.run(json.loads(os.environ["READINESS_PROBE"])).returncode)
elif args[:2] == ["compose", "-f"] and "stop" in args:
    print("compose stop progress")
    if mode == "provider-warning":
        print("podman: warning from stop", file=sys.stderr)
    (root / "stopped").touch()
    if os.environ.get("FAIL_PHASE") == "stop":
        print("compose stop failure detail")
        sys.exit(38)
elif args[:2] == ["compose", "-f"] and "up" in args:
    (root / "stopped").unlink()
'''
UPDATER = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["AIAGENT_UPDATE_TEST_ROOT"])
assert (root / "stopped").exists()
(root / "updater-args").write_text(json.dumps(sys.argv[1:]))
(root / "updater-env").write_text(json.dumps({
    "hook": os.environ.get("GAK_SERVICES_SHOW_HOOK_OUTPUT"),
    "provider": os.environ.get("GAK_SERVICES_SHOW_PROVIDER_ERRORS"),
}))
print("shared updater progress")
print("shared updater warning", file=sys.stderr)
if os.environ.get("FAIL_AFTER_APPLY"):
    (root / "pin-present").touch()
    sys.exit(1)
(root / "accepted").touch()
'''
T3 = '''#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, HTTPServer
import os
import sys

if os.environ.get("T3_TEST_MODE") == "exit":
    sys.exit(1)
port = int(sys.argv[sys.argv.index("--port") + 1])
mode = os.environ.get("T3_TEST_MODE", "healthy")
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(503 if mode == "wrong" else 200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"T3 test server")
    def log_message(self, *_args):
        pass
server = HTTPServer(("127.0.0.1", port), Handler)
if mode == "wrong":
    server.handle_request()
else:
    server.serve_forever()
'''


def replace(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def backup_progress(root):
    module = importlib.machinery.SourceFileLoader("aiagent_update_probe", str(SOURCE)).load_module()
    module.REQUEST = root / "request"
    module.RESULT = root / "result"
    clock = [0]
    output = io.StringIO()

    def sleep(seconds):
        clock[0] += seconds
        if clock[0] == 62:
            nonce = module.REQUEST.read_text().strip()
            module.RESULT.write_text(f"ok {nonce}\n")

    with mock.patch.object(module.time, "monotonic", side_effect=lambda: clock[0]), \
            mock.patch.object(module.time, "sleep", side_effect=sleep), \
            contextlib.redirect_stdout(output):
        module.backup()
    assert "waiting for scheduled backup\n" in output.getvalue()
    assert "waiting for scheduled backup (60s elapsed)" in output.getvalue()
    assert not module.REQUEST.exists() and not module.RESULT.exists()


def timeout_diagnostics(root):
    module = importlib.machinery.SourceFileLoader("aiagent_update_timeout_probe", str(SOURCE)).load_module()
    stalled = root / "stalled"
    stalled.write_text('''#!/usr/bin/env python3
import time
print("partial progress before timeout", flush=True)
time.sleep(5)
''')
    stalled.chmod(0o755)
    errors = io.StringIO()
    with contextlib.redirect_stderr(errors):
        try:
            module.command(str(stalled), "work", timeout=0.2)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise AssertionError("command timeout was ignored")
    assert "partial progress before timeout" in errors.getvalue()


def build_timeout_diagnostics(root):
    module = importlib.machinery.SourceFileLoader("aiagent_build_timeout_probe", str(SOURCE)).load_module()
    stalled = root / "stalled-build"
    stalled.write_text('''#!/usr/bin/env python3
import sys
import time
print("partial build stdout", flush=True)
print("partial build stderr", file=sys.stderr, flush=True)
time.sleep(5)
''')
    stalled.chmod(0o755)
    errors = io.StringIO()
    with contextlib.redirect_stderr(errors):
        try:
            module.command(str(stalled), "build", timeout=0.2, quiet_build=True)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise AssertionError("build timeout was ignored")
    assert "partial build stdout" in errors.getvalue()
    assert "partial build stderr" in errors.getvalue()
    assert "rerun aiagent update --verbose" in errors.getvalue()


def exercise(root, probe, broken=False, postapply=False, verbose=False,
             same_image=False, fail_phase=None, stop_mode="graceful"):
    home = root / "home"
    (home / "image").mkdir(parents=True)
    (home / "image/Containerfile").write_text("FROM scratch\n")
    (home / "services/agent").mkdir(parents=True)
    (home / "services/agent/compose.yaml").write_text("name: agent\n")
    (home / "workspaces").mkdir()
    (home / "container-home").mkdir()
    (home / "workspaces/sentinel").write_text("workspace state")
    (home / "container-home/sentinel").write_text("login state")
    (home / ".guix-profile/bin").mkdir(parents=True)
    (home / ".local/bin").mkdir(parents=True)
    updater = home / ".guix-profile/bin/gak-services"
    updater.write_text(UPDATER)
    updater.chmod(0o755)
    fake = root / "podman"
    new_image = OLD if same_image else NEW
    fake.write_text(PODMAN % (OLD, new_image, OLD, new_image))
    fake.chmod(0o755)
    stop_source = STOP_SOURCE.read_text()
    stop_source = replace(stop_source, 'HOME = Path("/home/aiagent")', f"HOME = Path({str(home)!r})")
    stop_source = replace(stop_source, 'PODMAN = "/run/current-system/profile/bin/podman"', f"PODMAN = {str(fake)!r}")
    stop_helper = home / ".local/bin/aiagent-stop-outcome"
    stop_helper.write_text(stop_source)
    stop_helper.chmod(0o755)
    source = SOURCE.read_text()
    source = replace(source, 'HOME = Path("/home/aiagent")', f"HOME = Path({str(home)!r})")
    source = replace(source, 'PODMAN = "/run/current-system/profile/bin/podman"', f"PODMAN = {str(fake)!r}")
    source = replace(source, 'REQUEST = Path("/run/aiagent/backup-request")', f"REQUEST = Path({str(root / 'request')!r})")
    source = replace(source, 'RESULT = Path("/run/aiagent/backup-result")', f"RESULT = Path({str(root / 'result')!r})")
    script = root / "aiagent-update"
    script.write_text(source)
    script.chmod(0o755)
    env = dict(os.environ, AIAGENT_UPDATE_TEST_ROOT=str(root),
               READINESS_PROBE=json.dumps(probe), STOP_MODE=stop_mode)
    if stop_mode == "historical":
        (root / "stopped").touch()
    if postapply:
        env["FAIL_AFTER_APPLY"] = "1"
    if fail_phase:
        env["FAIL_PHASE"] = fail_phase

    def answer_backup():
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if (root / "request").exists():
                assert (root / "stopped").exists()
                assert (home / "workspaces/sentinel").read_text() == "workspace state"
                assert (home / "container-home/sentinel").read_text() == "login state"
                nonce = (root / "request").read_text().strip()
                (root / "result").write_text(f"ok {nonce}\n")
                return
            time.sleep(0.02)
        raise AssertionError("backup was not requested")

    responder = None
    if not broken and fail_phase not in ("build", "build-large", "stop") and stop_mode not in ("forced", "replacement"):
        responder = threading.Thread(target=answer_backup)
        responder.start()
    result = subprocess.run([script] + (["--verbose"] if verbose else []),
                            env=env, capture_output=True, text=True, timeout=15)
    if responder:
        responder.join(timeout=10)
    failed = broken or postapply or fail_phase or stop_mode in ("forced", "replacement")
    assert result.returncode == (1 if failed else 0), result.stderr
    calls = (root / "calls").read_text().splitlines()
    assert all('"pull"' not in call for call in calls)
    if fail_phase not in ("build", "build-large"):
        assert any('"/usr/local/bin/aiagent-readiness"' in call for call in calls)
    assert (home / "workspaces/sentinel").read_text() == "workspace state"
    assert (home / "container-home/sentinel").read_text() == "login state"
    if fail_phase in ("build", "build-large", "stop"):
        assert (root / "stopped").exists() == (fail_phase == "stop")
        assert not (root / "updater-args").exists()
        if fail_phase == "build" and verbose:
            assert "build failure detail from podman" in result.stdout
            assert "build progress from podman" in result.stdout
            assert "Fedora 44 - Updates: repository metadata" in result.stderr
            assert "build failure stderr detail" in result.stderr
            assert "rerun aiagent update --verbose" not in result.stderr
        elif fail_phase == "build-large":
            assert "final build failure detail" in result.stderr
            assert "early build detail that must be truncated" not in result.stderr
            assert "build output truncated" in result.stderr
            assert len(result.stderr) < 20000
        else:
            assert f"{fail_phase} failure detail" in result.stderr
            if fail_phase == "build":
                assert "build failure stderr detail" in result.stderr
        command = "build" if fail_phase != "stop" else "aiagent-stop-outcome"
        assert f"{command} exited" in result.stderr
        if fail_phase != "stop" and not verbose:
            assert "Fedora 44 - Updates: repository metadata" in result.stderr or fail_phase == "build-large"
            assert "rerun aiagent update --verbose" in result.stderr
        if fail_phase == "stop":
            assert "Compose stop exited 38" in result.stderr
            assert "backup and image application were skipped" in result.stderr
            assert "stop was forced or could not be verified" in result.stderr
            assert not (root / "request").exists()
    elif stop_mode in ("forced", "replacement"):
        assert (root / "stopped").exists()
        assert not (root / "request").exists()
        assert not (root / "updater-args").exists()
        assert "backup and image application were skipped" in result.stderr
        assert "stop was forced or could not be verified" in result.stderr
        assert "agent may remain stopped" in result.stderr
        if stop_mode == "forced":
            assert "shutdown escalated" in result.stderr and "exit 124" in result.stderr
        else:
            assert "identity changed" in result.stderr
    elif broken:
        assert not (root / "stopped").exists()
        assert not (root / "updater-args").exists()
    elif postapply:
        assert (root / "stopped").exists()
        assert (root / "pin-present").exists()
        assert f"previous image {OLD[:12]} retained at localhost/gak-services-previous:" in result.stderr
        assert "GAK-SERVICES.org" in result.stderr
        assert not any('"up"' in call for call in calls)
    else:
        assert "--from-stopped" in (root / "updater-args").read_text()
        assert f"agent={new_image}" in (root / "updater-args").read_text()
        if stop_mode == "provider-warning":
            assert "podman: warning from stop" in result.stderr
        if stop_mode == "historical":
            assert "historical exit 124" in result.stderr
            assert "shutdown escalated" not in result.stderr
        if stop_mode == "absent":
            assert "shutdown escalated" not in result.stderr
        assert "shared updater warning" in result.stderr
        assert "building candidate image" in result.stdout
        assert "backing up persistent state" in result.stdout
        assert "applying image and configuration" in result.stdout
        if verbose:
            assert "readiness hook output, which may contain private data" in result.stderr
            assert "build progress from podman" in result.stdout
            assert "Fedora 44 - Updates: repository metadata" in result.stderr
            assert "[1/117] Installing nodejs" in result.stderr
            assert "compose stop progress" in result.stdout
            assert "shared updater progress" in result.stdout
        else:
            assert "build progress from podman" not in result.stdout
            assert "Fedora 44 - Updates: repository metadata" not in result.stderr
            assert "[1/117] Installing nodejs" not in result.stderr
            assert "compose stop progress" not in result.stdout
            assert "shared updater progress" not in result.stdout
        updater_env = json.loads((root / "updater-env").read_text())
        assert updater_env == {"hook": "1" if verbose else None, "provider": None}
        if same_image:
            assert f"image unchanged ({OLD[:12]})" in result.stdout
            assert "previous image" not in result.stdout
        else:
            assert f"accepted image {NEW[:12]}" in result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix="aiagent-update-", dir=Path.home() / ".cache") as scratch:
        root = Path(scratch)
        backup_progress(root)
        timeout_diagnostics(root)
        build_timeout_diagnostics(root)
        binaries = root / "bin"
        tools = root / "local"
        binaries.mkdir()
        tools.mkdir()
        for name in ("sh", "env", "python3"):
            shutil.copy2(Path(shutil.which(name)).resolve(), binaries / name)
        shutil.copy2(READINESS, tools / "aiagent-readiness")
        for name in ("t3", "t3-web"):
            (tools / name).write_text("#!/bin/sh\nexit 0\n")
            (tools / name).chmod(0o755)
        (tools / "aiagent-provider-prefix").write_text(
            '#!/bin/sh\n[ "${FAKE_PREFIX_FAIL:-0}" != 1 ]\n'
        )
        (tools / "aiagent-provider-prefix").chmod(0o755)
        (tools / "t3-native").write_text(T3)
        (tools / "t3-native").chmod(0o755)

        def probe(missing_dir=None, mode="--candidate"):
            argv = ["bwrap", "--unshare-all", "--share-net", "--die-with-parent", "--tmpfs", "/",
                    "--dev", "/dev", "--ro-bind", "/usr/lib", "/usr/lib",
                    "--symlink", "usr/lib", "/lib", "--symlink", "usr/lib", "/lib64",
                    "--ro-bind", str(binaries), "/usr/bin", "--symlink", "usr/bin", "/bin",
                    "--ro-bind", str(tools), "/usr/local/bin"]
            for directory in ("/home/node", "/work", "/cache"):
                if directory != missing_dir:
                    argv.extend(("--dir", directory))
            if missing_dir != "/cache":
                argv.extend(("--dir", "/cache/tmp"))
            return [*argv, "/usr/local/bin/aiagent-readiness", mode]

        assert subprocess.run(probe()).returncode == 0
        for directory in ("/home/node", "/work", "/cache"):
            case = root / ("missing-dir-" + directory.replace("/", "-"))
            case.mkdir()
            exercise(case, probe(directory), broken=True)
            print(f"missing {directory}: candidate refused before compose stop")
        for name in ("t3", "t3-native", "t3-web", "aiagent-provider-prefix"):
            command = tools / name
            disabled = tools / (name + ".disabled")
            command.rename(disabled)
            try:
                case = root / ("missing-tool-" + name)
                case.mkdir()
                exercise(case, probe(), broken=True)
            finally:
                disabled.rename(command)
            print(f"missing {name}: candidate refused before compose stop")

        os.environ["FAKE_PREFIX_FAIL"] = "1"
        try:
            case = root / "invalid-provider-seed"
            case.mkdir()
            exercise(case, probe(), broken=True)
        finally:
            os.environ.pop("FAKE_PREFIX_FAIL")
        print("invalid provider seed: candidate refused before compose stop")

        for mode in ("exit", "wrong"):
            case = root / ("t3-" + mode)
            case.mkdir()
            os.environ["T3_TEST_MODE"] = mode
            try:
                exercise(case, probe(), broken=True)
            finally:
                os.environ.pop("T3_TEST_MODE")
            print(f"T3 {mode}: candidate refused before compose stop")

        assert subprocess.run(probe(mode="--live")).returncode != 0
        server = subprocess.Popen([tools / "t3-native", "serve", "--port", "3773"])
        try:
            for _ in range(50):
                if subprocess.run(probe(mode="--live"), capture_output=True).returncode == 0:
                    break
                time.sleep(0.05)
            else:
                raise AssertionError("live readiness did not accept a serving T3")
        finally:
            server.terminate()
            server.wait(timeout=5)
        assert subprocess.run(probe(mode="--live")).returncode != 0
        print("deployed readiness required a live HTTP server and rejected its shutdown")

        print("candidate and live readiness accepted optional provider uninstalls")

        for name, postapply in (("accepted", False), ("postapply-failure", True)):
            case = root / name
            case.mkdir()
            exercise(case, probe(), postapply=postapply)
        for name, options in (
            ("verbose", {"verbose": True}),
            ("unchanged", {"same_image": True}),
            ("build-failure", {"fail_phase": "build"}),
            ("verbose-build-failure", {"fail_phase": "build", "verbose": True}),
            ("build-large-failure", {"fail_phase": "build-large"}),
            ("stop-failure", {"fail_phase": "stop"}),
            ("forced-stop", {"stop_mode": "forced"}),
            ("replacement-stop", {"stop_mode": "replacement"}),
            ("historical-stop", {"stop_mode": "historical"}),
            ("absent-stop", {"stop_mode": "absent"}),
            ("provider-warning", {"stop_mode": "provider-warning"}),
        ):
            case = root / name
            case.mkdir()
            exercise(case, probe(), **options)
    print("accepted update followed a stopped snapshot")
    print("post-apply failure named the retained previous tag and manual rollback without auto rollback")
    print("quiet and verbose progress, unchanged image, warnings and command failures verified")
    print("scheduled backup wait reported elapsed progress and cleared its request")
    print("timed-out command replayed captured progress")
    print("quiet build captured both streams and replayed bounded failure and timeout tails")


if __name__ == "__main__":
    main()
