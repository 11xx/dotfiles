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
import stat
import subprocess
import sys
import tempfile


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
NOFOLLOW = os.O_NOFOLLOW | os.O_CLOEXEC


class Busy(Exception):
    pass


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


def command(*arguments, timeout=None, capture=False):
    return subprocess.run(arguments, check=True, timeout=timeout,
                          capture_output=capture, text=capture)


def validate_password():
    metadata = PASSWORD.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != 0 or stat.S_IMODE(metadata.st_mode) != 0o600:
        raise RuntimeError("backup password file must be root-owned mode 0600")


def snapshot():
    validate_password()
    if subprocess.run(("findmnt", "-n", "--mountpoint", str(HOME)),
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
        subprocess.run(argv, check=True, env=environment)

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
    return process_identity(pid) == started


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
    for attempt in range(2):
        try:
            started = subprocess.run(("herd", "start", SERVICE), timeout=START_TIMEOUT)
            status = started.returncode
        except subprocess.TimeoutExpired:
            status = 124
        if status == 0:
            return
        if attempt == 0:
            try:
                subprocess.run(("herd", "enable", SERVICE), timeout=START_TIMEOUT)
            except subprocess.TimeoutExpired:
                pass
    raise RuntimeError("agent Compose service did not restart")


def quiesced(action):
    try:
        command("herd", "stop", SERVICE, timeout=STOP_TIMEOUT)
        action()
    finally:
        recover_service()


def manifest(root):
    entries = {}

    def visit(path):
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
        subprocess.run(("restic", "--quiet", "restore", "latest", "--host", "gak",
                        "--tag", "aiagent", "--target", str(scratch)),
                       check=True, env=environment)
        restored = scratch / HOME.relative_to("/")
        if manifest(HOME) != manifest(restored):
            raise RuntimeError("agent restore checksums or paths differ")
        print("agent restore checksums match")
    finally:
        shutil.rmtree(scratch)


def main(operation):
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


if __name__ == "__main__":
    try:
        main(sys.argv[1] if len(sys.argv) == 2 else "")
    except Busy as error:
        print(f"agent backup: {error}", file=sys.stderr)
        sys.exit(75)
    except (OSError, RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"agent backup: {error}", file=sys.stderr)
        sys.exit(1)
