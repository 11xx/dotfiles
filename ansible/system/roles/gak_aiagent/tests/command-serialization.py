#!/usr/bin/env python3
"""Exercise operation ordering when the caller exits before its child."""

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


ROLE = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("AIAGENT_OPERATION_SOURCE", ROLE / "files/aiagent-operation"))
COMMAND = Path(os.environ.get("AIAGENT_COMMAND_SOURCE", ROLE / "files/aiagent"))
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

operation = sys.argv[-1]
if operation in ("stop", "restart"):
    assert (root / "service/cli/cgroup.procs").read_text() == str(os.getpid())
with (root / "events").open("a") as events:
    events.write(operation + "\\n")
if operation == "stop":
    while not (root / "release").exists():
        time.sleep(0.05)
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
        first = subprocess.Popen([command, "stop"], env=env)
        second = None
        try:
            wait_until(lambda: (root / "events").exists())
            first.send_signal(signal.SIGKILL)
            first.wait(timeout=5)
            second = subprocess.Popen([command, "restart"], env=env)
            time.sleep(0.4)
            assert (root / "events").read_text().splitlines() == ["stop"]
            (root / "release").touch()
            assert second.wait(timeout=5) == 0
            assert (root / "events").read_text().splitlines() == ["stop", "restart"]
            assert not (root / "aiagent.active").exists()
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
            print("supervisor killed: restart waited for stop child; lock not inherited")
            print("cache cleanup stayed inside the cache subtree")
        finally:
            (root / "release").touch()
            if second is not None and second.poll() is None:
                second.kill()
                second.wait()
            if first.poll() is None:
                first.kill()
                first.wait()


if __name__ == "__main__":
    main()
