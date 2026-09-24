#!/usr/bin/env python3
"""Exercise operation ordering across caller and worker deaths."""

import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace


ROLE = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("AIAGENT_OPERATION_SOURCE", ROLE / "files/aiagent-operation"))
COMMAND = Path(os.environ.get("AIAGENT_COMMAND_SOURCE", ROLE / "files/aiagent"))
BACKUP = ROLE.parent / "guix_config/files/modules/aiagent/backup.py"
FAKE_PODMAN = '''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import time

root = Path(os.environ["AIAGENT_PROBE_ROOT"])
lock = root / "aiagent.lock"
for fd in Path("/proc/self/fd").iterdir():
    try:
        assert fd.resolve() != lock, "Podman inherited the operation lock"
    except FileNotFoundError:
        pass

operation = "up" if "up" in sys.argv else sys.argv[-1]
if operation in ("stop", "up"):
    assert (root / "service/cli/cgroup.procs").read_text() in (str(os.getpid()), str(os.getppid()))
if operation == "up":
    assert sys.argv[sys.argv.index("--pull") + 1] == "never"
with (root / "events").open("a") as events:
    events.write(operation + "\\n")
if operation == "stop":
    if os.getpid() != os.getsid(0):
        os.setpgid(0, 0)
    (root / "stop-child.pid").write_text(str(os.getpid()))
    while not (root / "release").exists():
        time.sleep(0.05)
if operation == "up" and (root / "spawn-detached").exists():
    import subprocess
    detached = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"],
                                start_new_session=True, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL)
    (root / "detached.pid").write_text(str(detached.pid))
'''


def wait_until(predicate, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("timed out waiting for operation")


def replace_one(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def main():
    with tempfile.TemporaryDirectory(prefix="aiagent-operation-", dir=Path.home() / ".cache") as temporary:
        root = Path(temporary)
        home = root / "home"
        (home / ".local/bin").mkdir(parents=True)
        fake = root / "podman"
        fake.write_text(FAKE_PODMAN)
        fake.chmod(0o755)
        helper = home / ".local/bin/aiagent-operation"
        source = SOURCE.read_text()
        source = replace_one(source, 'HOME = Path("/home/aiagent")', f'HOME = Path({str(home)!r})')
        source = replace_one(source, 'PODMAN = "/run/current-system/profile/bin/podman"', f'PODMAN = {str(fake)!r}')
        source = replace_one(source, 'LOCK = Path("/run/aiagent/aiagent.lock")', f'LOCK = Path({str(root / "aiagent.lock")!r})')
        source = replace_one(source, 'ACTIVE = Path("/run/aiagent/aiagent.active")', f'ACTIVE = Path({str(root / "aiagent.active")!r})')
        source = replace_one(source, 'PROJECT_CGROUP = Path("/sys/fs/cgroup/aiagent/delegated/service/cli")',
                             f'PROJECT_CGROUP = Path({str(root / "service/cli")!r})')
        helper.write_text(source)
        helper.chmod(0o750)
        command = root / "aiagent"
        command.write_text(replace_one(COMMAND.read_text(), "home=/home/aiagent", f"home={home}"))
        command.chmod(0o750)
        env = dict(os.environ, AIAGENT_PROBE_ROOT=str(root))
        spec = importlib.util.spec_from_file_location("agent_backup", BACKUP)
        backup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(backup)
        backup.RUNTIME = root
        backup.agent_account = lambda: SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid())
        first = subprocess.Popen([command, "stop"], env=env)
        second = None
        crashed = None
        following = None
        detached_pid = None
        try:
            wait_until(lambda: (root / "events").exists())
            first.send_signal(signal.SIGKILL)
            first.wait(timeout=5)
            for caller in ("daily", "restore-check"):
                try:
                    backup.operation_lock()
                except backup.Busy:
                    pass
                else:
                    raise AssertionError(f"{caller} ignored the surviving worker")
            second = subprocess.Popen([command, "restart"], env=env)
            time.sleep(0.4)
            assert (root / "events").read_text().splitlines() == ["stop"]
            (root / "release").touch()
            assert second.wait(timeout=5) == 0
            assert (root / "events").read_text().splitlines() == ["stop", "stop", "up"]
            assert not (root / "aiagent.active").exists()
            operation_descriptor = backup.operation_lock()
            os.close(operation_descriptor)

            (root / "release").unlink()
            (root / "events").unlink()
            crashed = subprocess.Popen([command, "restart"], env=env)
            wait_until(lambda: (root / "events").exists())
            assert (root / "events").read_text().splitlines() == ["stop"]
            record = json.loads((root / "aiagent.active").read_text())
            os.kill(record["pid"], signal.SIGKILL)
            assert crashed.wait(timeout=5) != 0
            stop_pid = int((root / "stop-child.pid").read_text())
            assert Path(f"/proc/{stop_pid}/stat").exists()
            assert os.getpgid(stop_pid) != record["pid"]
            assert os.getsid(stop_pid) == record["pid"]
            for caller in ("daily", "restore-check"):
                try:
                    backup.operation_lock()
                except backup.Busy:
                    pass
                else:
                    raise AssertionError(f"{caller} ignored the surviving Compose child")
            following = subprocess.Popen([command, "recreate"], env=env)
            time.sleep(0.4)
            assert (root / "events").read_text().splitlines() == ["stop"]
            (root / "release").touch()
            assert following.wait(timeout=5) == 0
            assert (root / "events").read_text().splitlines() == ["stop", "up"]
            assert not (root / "aiagent.active").exists()
            operation_descriptor = backup.operation_lock()
            os.close(operation_descriptor)

            (root / "spawn-detached").touch()
            assert subprocess.run([command, "recreate"], env=env).returncode == 0
            detached_pid = int((root / "detached.pid").read_text())
            assert Path(f"/proc/{detached_pid}/stat").exists()
            assert not (root / "aiagent.active").exists()
            operation_descriptor = backup.operation_lock()
            os.close(operation_descriptor)
            cache = home / "cache"
            (cache / "data").mkdir(parents=True)
            (cache / "data/file").write_text("disposable")
            outside = root / "keep"
            outside.write_text("persistent")
            (cache / "link").symlink_to(outside)
            assert subprocess.run([command, "cache-clean"], env=env).returncode == 0
            assert not (cache / "data").exists()
            assert not (cache / "link").exists()
            assert outside.read_text() == "persistent"
            assert all((cache / name).is_dir() for name in ("tmp", "npm", "xdg"))
            print("caller death: restart waited for the surviving stop worker")
            print("worker death: recreate and backup waited for the surviving Compose child")
            print("detached workload did not retain the operation record or lock")
            print("cache cleanup stayed inside the cache subtree")
        finally:
            (root / "release").touch()
            if detached_pid is not None:
                try:
                    os.kill(detached_pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            for process in (following, crashed):
                if process is not None and process.poll() is None:
                    process.kill()
                    process.wait()
            if second is not None and second.poll() is None:
                second.kill()
                second.wait()
            if first.poll() is None:
                first.kill()
                first.wait()


if __name__ == "__main__":
    main()
