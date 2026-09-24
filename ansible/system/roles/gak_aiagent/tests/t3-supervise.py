#!/usr/bin/env python3
"""Exercise the image supervisor with an isolated native and harness process tree."""

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


ROLE = Path(__file__).resolve().parents[1]
SOURCE = ROLE / "files/image/bin/t3-supervise"
SERVER = '''#!/usr/bin/env python3
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

root = Path(os.environ["SUPERVISOR_TEST_ROOT"])
mode = os.environ["SUPERVISOR_TEST_MODE"]
identity = Path(f"/proc/{os.getpid()}/stat").read_text().rsplit(")", 1)[1].split()[19]
with (root / "starts").open("a") as log:
    log.write(f"{os.getpid()} {identity}\\n")
if mode == "restart" and len((root / "starts").read_text().splitlines()) == 1:
    sys.exit(7)
child = subprocess.Popen([sys.executable, str(root / "harness")])
def terminate(_number, _frame):
    (root / "native-term").touch()
    if mode != "stubborn":
        child.send_signal(signal.SIGTERM)
        if mode != "orphan":
            child.wait(timeout=5)
        sys.exit(0)
signal.signal(signal.SIGTERM, terminate)
while True:
    time.sleep(0.1)
'''
HARNESS = '''#!/usr/bin/env python3
import os
from pathlib import Path
import signal
import sys
import time

root = Path(os.environ["SUPERVISOR_TEST_ROOT"])
identity = Path(f"/proc/{os.getpid()}/stat").read_text().rsplit(")", 1)[1].split()[19]
(root / "harness-pid").write_text(f"{os.getpid()} {identity}")
def terminate(_number, _frame):
    (root / "harness-term").touch()
    if os.environ["SUPERVISOR_TEST_MODE"] not in ("stubborn", "orphan"):
        time.sleep(0.2)
        sys.exit(0)
signal.signal(signal.SIGTERM, terminate)
(root / "harness-ready").touch()
while True:
    time.sleep(0.1)
'''


def active(pid, started):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    except FileNotFoundError:
        return False
    return fields[0] not in ("Z", "X") and fields[19] == started


def kill_owned(pid, started):
    try:
        descriptor = os.pidfd_open(pid)
    except ProcessLookupError:
        return
    try:
        if active(pid, started):
            signal.pidfd_send_signal(descriptor, signal.SIGKILL)
    finally:
        os.close(descriptor)


def await_file(path, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        time.sleep(0.05)
    raise AssertionError(f"missing event: {path.name}")


def exercise(root, mode):
    root.mkdir()
    server = root / "t3-web"
    server.write_text(SERVER)
    server.chmod(0o755)
    harness = root / "harness"
    harness.write_text(HARNESS)
    harness.chmod(0o755)
    source = SOURCE.read_text()
    assert source.count('SERVER = "/usr/local/bin/t3-web"') == 1
    source = source.replace('SERVER = "/usr/local/bin/t3-web"', f"SERVER = {str(server)!r}")
    source = source.replace("STOP_GRACE = 40", "STOP_GRACE = 1")
    source = source.replace("GROUP_GRACE = 3", "GROUP_GRACE = 0.4")
    source = source.replace("RESTART_DELAY = 2", "RESTART_DELAY = 0.2")
    supervisor = root / "t3-supervise"
    supervisor.write_text(source)
    supervisor.chmod(0o755)
    env = dict(os.environ, SUPERVISOR_TEST_ROOT=str(root), SUPERVISOR_TEST_MODE=mode)
    process = subprocess.Popen([supervisor], env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    try:
        await_file(root / "harness-ready")
        if mode == "restart":
            assert len((root / "starts").read_text().splitlines()) == 2
        native_pid, native_start = (root / "starts").read_text().splitlines()[-1].split()
        harness_pid, harness_start = (root / "harness-pid").read_text().split()
        native_pid, harness_pid = int(native_pid), int(harness_pid)
        assert active(native_pid, native_start) and active(harness_pid, harness_start)
        started = time.monotonic()
        process.send_signal(signal.SIGTERM)
        _, errors = process.communicate(timeout=5)
        assert process.returncode == (124 if mode in ("stubborn", "orphan") else 0), errors
        assert time.monotonic() - started < 3
        await_file(root / "native-term")
        if mode in ("stubborn", "orphan"):
            await_file(root / "harness-term")
            assert "exceeded its stop grace" in errors
        else:
            await_file(root / "harness-term")
            assert "exceeded its stop grace" not in errors
        assert not active(native_pid, native_start), native_pid
        assert not active(harness_pid, harness_start), harness_pid
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        for name in ("starts", "harness-pid"):
            path = root / name
            if path.exists():
                for record in path.read_text().splitlines():
                    pid, started = record.split()
                    kill_owned(int(pid), started)


def main():
    with tempfile.TemporaryDirectory(prefix="t3-supervise-", dir=Path.home() / ".cache") as scratch:
        for mode in ("graceful", "stubborn", "orphan", "restart"):
            exercise(Path(scratch) / mode, mode)
            print(f"{mode}: owned T3 group stopped and reaped")


if __name__ == "__main__":
    main()
