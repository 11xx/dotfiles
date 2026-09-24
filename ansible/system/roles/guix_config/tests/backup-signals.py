#!/usr/bin/env python3
"""Rehearse termination during a stopped-service snapshot and restore."""

import fcntl
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


SOURCE = Path(__file__).resolve().parents[1] / "files/modules/aiagent/backup.py"
RESTIC = '''import os
from pathlib import Path
import subprocess
import sys
import time
root = Path(sys.argv[1])
mode = sys.argv[2]
child_code = "import time; time.sleep(60)"
if mode == "restore-check":
    child_code = "import signal,time; from pathlib import Path; signal.signal(signal.SIGTERM, signal.SIG_IGN); Path('" + str(root / "child-ready") + "').touch(); time.sleep(60)"
child = subprocess.Popen([sys.executable, "-c", child_code])
(root / "grandchild.pid").write_text(str(child.pid))
if mode == "restore-check":
    for _ in range(100):
        if (root / "child-ready").exists():
            break
        time.sleep(0.01)
(root / "restic.pid").write_text(str(os.getpid()))
time.sleep(60)
'''
RUNNER = '''import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from types import SimpleNamespace
root = Path(os.environ["BACKUP_PROBE_ROOT"])
spec = importlib.util.spec_from_file_location("agent_backup", os.environ["BACKUP_SOURCE"])
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)
backup.STATE = root
backup.RUNTIME = root
backup.RESULT_ROOT = root
backup.root_directory = lambda *_args, **_kwargs: None
backup.validate_password = lambda: None
backup.agent_account = lambda: SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid())
backup.os.geteuid = lambda: 0
backup.command = lambda *_args, **_kwargs: (root / "stopped").touch()
def action():
    backup.run_process((sys.executable, "-c", os.environ["RESTIC_PROBE"], str(root),
                        os.environ["BACKUP_MODE"]), check=True)
def recover():
    (root / "recovering").touch()
    time.sleep(1)
    (root / "recovered").touch()
backup.recover_service = recover
backup.snapshot = action
backup.restore_check = action
try:
    backup.main(os.environ["BACKUP_MODE"])
except backup.Interrupted as error:
    sys.exit(128 + error.signum)
'''
REVIEWER = '''import importlib.util
import os
from pathlib import Path
import signal
spec = importlib.util.spec_from_file_location("agent_backup", os.environ["BACKUP_SOURCE"])
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)
backup.command = lambda *_args, **_kwargs: None
backup.recover_service = lambda: Path(os.environ["RECOVERY_MARKER"]).write_text("recovered")
backup.quiesced(lambda: os.kill(os.getpid(), getattr(signal, os.environ["FIRST_SIGNAL"])))
'''
TRANSITION = '''import importlib.util
import inspect
import os
from pathlib import Path
import signal
import sys
import time
from types import SimpleNamespace
root = Path(os.environ["BACKUP_PROBE_ROOT"])
point = os.environ["BACKUP_TRANSITION"]
spec = importlib.util.spec_from_file_location("agent_backup", os.environ["BACKUP_SOURCE"])
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)
backup.STATE = root
backup.RUNTIME = root
backup.RESULT_ROOT = root
backup.root_directory = lambda *_args, **_kwargs: None
backup.validate_password = lambda: None
backup.agent_account = lambda: SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid())
backup.os.geteuid = lambda: 0
backup.command = lambda *_args, **_kwargs: (root / "stopped").touch()
def action():
    if point == "snapshot":
        os.kill(os.getpid(), signal.SIGTERM)
backup.snapshot = action
def recover():
    if point == "recovery":
        os.kill(os.getpid(), signal.SIGTERM)
    (root / "recovering").touch()
    time.sleep(1)
    (root / "recovered").touch()
backup.recover_service = recover
if point == "before-stop":
    original = backup.check_interrupted
    sent = False
    def check():
        global sent
        if not sent:
            sent = True
            os.kill(os.getpid(), signal.SIGTERM)
        return original()
    backup.check_interrupted = check
if point == "finally-entry":
    lines, first = inspect.getsourcelines(backup.quiesced)
    target = next(first + index for index, line in enumerate(lines)
                  if line.strip() == "recover_service()")
    sent = False
    def trace(frame, event, arg):
        global sent
        if not sent and event == "line" and frame.f_code.co_name == "quiesced" and frame.f_lineno == target:
            sent = True
            os.kill(os.getpid(), signal.SIGTERM)
        return trace
    sys.settrace(trace)
try:
    backup.main("daily")
except backup.Interrupted as error:
    sys.exit(128 + error.signum)
'''
STALLED = '''import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
from types import SimpleNamespace
root = Path(os.environ["BACKUP_PROBE_ROOT"])
spec = importlib.util.spec_from_file_location("agent_backup", os.environ["BACKUP_SOURCE"])
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)
backup.STATE = root
backup.RUNTIME = root
backup.RESULT_ROOT = root
backup.root_directory = lambda *_args, **_kwargs: None
backup.validate_password = lambda: None
backup.agent_account = lambda: SimpleNamespace(pw_uid=os.getuid(), pw_gid=os.getgid())
backup.os.geteuid = lambda: 0
backup.command = lambda *_args, **_kwargs: None
backup.snapshot = lambda: os.kill(os.getpid(), signal.SIGTERM)
backup.START_TIMEOUT = 0.25
backup.RECOVERY_TIMEOUT = 0.8
original = backup.run_process
def run(arguments, **kwargs):
    if arguments[0] == "findmnt":
        return subprocess.CompletedProcess(arguments, 0)
    return original((sys.executable, "-c", "import time; time.sleep(60)"),
                    timeout=kwargs["timeout"], ignore_interrupt=True)
backup.run_process = run
try:
    backup.main("daily")
except (RuntimeError, subprocess.TimeoutExpired):
    sys.exit(1)
'''


def wait_for(path, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        time.sleep(0.02)
    raise AssertionError(f"timed out waiting for {path.name}")


def lock_available(path):
    with path.open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
        return True


def alive(pid):
    try:
        state = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[0]
    except FileNotFoundError:
        return False
    return state not in ("Z", "X")


def exercise(root, mode):
    case = root / mode
    case.mkdir()
    (case / "aiagent.lock").touch()
    environment = dict(os.environ, BACKUP_SOURCE=str(SOURCE), BACKUP_PROBE_ROOT=str(case),
                       BACKUP_MODE=mode, RESTIC_PROBE=RESTIC)
    process = subprocess.Popen([sys.executable, "-c", RUNNER], env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        wait_for(case / "restic.pid")
        started = time.monotonic()
        process.send_signal(signal.SIGTERM)
        wait_for(case / "recovering", timeout=20)
        assert not lock_available(case / "backup.lock")
        assert not lock_available(case / "aiagent.lock")
        process.send_signal(signal.SIGHUP)
        output, errors = process.communicate(timeout=8)
        assert process.returncode == 143, (output, errors, process.returncode)
        assert (case / "recovered").exists()
        assert lock_available(case / "backup.lock")
        assert lock_available(case / "aiagent.lock")
        assert not alive(int((case / "restic.pid").read_text()))
        assert not alive(int((case / "grandchild.pid").read_text()))
        assert time.monotonic() - started < 18
        print(f"{mode}: SIGTERM settled the child group; SIGHUP did not skip recovery; locks released after")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


def transition(root, point):
    case = root / point
    case.mkdir()
    (case / "aiagent.lock").touch()
    environment = dict(os.environ, BACKUP_SOURCE=str(SOURCE), BACKUP_PROBE_ROOT=str(case),
                       BACKUP_TRANSITION=point)
    process = subprocess.Popen([sys.executable, "-c", TRANSITION], env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        wait_for(case / "recovering")
        assert not lock_available(case / "backup.lock")
        assert not lock_available(case / "aiagent.lock")
        output, errors = process.communicate(timeout=5)
        assert process.returncode == 143, (point, output, errors, process.returncode)
        assert (case / "recovered").exists()
        assert lock_available(case / "backup.lock")
        assert lock_available(case / "aiagent.lock")
        print(f"{point}: recovery completed before both locks released")
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()


def stalled(root):
    case = root / "stalled"
    case.mkdir()
    (case / "aiagent.lock").touch()
    result = subprocess.run([sys.executable, "-c", STALLED],
                            env=dict(os.environ, BACKUP_SOURCE=str(SOURCE),
                                     BACKUP_PROBE_ROOT=str(case)),
                            capture_output=True, text=True, timeout=8)
    assert result.returncode == 1, (result.stdout, result.stderr, result.returncode)
    assert lock_available(case / "backup.lock")
    assert lock_available(case / "aiagent.lock")
    print("stalled recovery: bounded failure released both locks")


def main():
    with tempfile.TemporaryDirectory(prefix="gak-backup-signals-", dir=Path.home() / ".cache") as temporary:
        root = Path(temporary)
        for name in ("SIGTERM", "SIGINT", "SIGHUP"):
            marker = root / f"{name}-recovered"
            result = subprocess.run([sys.executable, "-c", REVIEWER],
                                    env=dict(os.environ, BACKUP_SOURCE=str(SOURCE),
                                             RECOVERY_MARKER=str(marker), FIRST_SIGNAL=name),
                                    capture_output=True, text=True)
            assert result.returncode != 0 and result.returncode != -getattr(signal, name)
            assert marker.read_text() == "recovered"
        print("reviewer signal reproductions: orderly nonzero exits after recovery")
        for point in ("before-stop", "snapshot", "finally-entry", "recovery"):
            transition(root, point)
        stalled(root)
        for mode in ("daily", "restore-check"):
            exercise(root, mode)


if __name__ == "__main__":
    main()
