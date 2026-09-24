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
                stdout=None, stderr=None, capture_output=False, text=False,
                ignore_interrupt=False):
    if not ignore_interrupt:
        check_interrupted()
    process = subprocess.Popen(
        arguments, env=env, stdout=subprocess.PIPE if capture_output else stdout,
        stderr=subprocess.PIPE if capture_output else stderr,
        text=text, start_new_session=True,
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

    if not (REPOSITORY / "config").is_file():
        restic("init")
    restic("backup", "--host", "gak", "--tag", "aiagent",
           str(HOME / "workspaces"), str(HOME / "container-home"))
    restic("forget", "--host", "gak", "--tag", "aiagent",
           "--keep-daily", "7", "--keep-weekly", "5", "--keep-monthly", "12", "--prune")
    restic("check")
    return environment


def process_identity(pid):
    try:
        fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    except FileNotFoundError:
        return None
    if fields[0] in ("Z", "X"):
        return None
    return fields[19]


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
        if fields[0] not in ("Z", "X") and fields[3] == str(pid):
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


def manifest(root):
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

    for name in ("workspaces", "container-home"):
        visit(root / name)
    return entries


def restore_check():
    environment = snapshot()
    scratch = Path(tempfile.mkdtemp(prefix="restore-check.", dir=BACKUP_ROOT))
    try:
        run_process(("restic", "--quiet", "restore", "latest", "--host", "gak",
                     "--tag", "aiagent", "--target", str(scratch)),
                    check=True, env=environment)
        restored = scratch / HOME.relative_to("/")
        if manifest(HOME) != manifest(restored):
            raise RuntimeError("agent restore checksums or paths differ")
        print("agent restore checksums match")
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
