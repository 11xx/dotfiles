#!/usr/bin/env python3
"""Rehearse root backup paths against a mapped unprivileged attacker."""

import importlib.util
import os
from pathlib import Path
import stat
import subprocess
import tempfile
from types import SimpleNamespace


SOURCE = Path(__file__).resolve().parents[1] / "files/modules/aiagent/backup.py"


def load_backup():
    spec = importlib.util.spec_from_file_location("agent_backup", SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def attacker(action):
    parent_read, child_write = os.pipe()
    pid = os.fork()
    if pid == 0:
        os.close(parent_read)
        os.setgid(1001)
        os.setuid(1001)
        try:
            action()
            os.write(child_write, b"ok")
        except PermissionError:
            os.write(child_write, b"denied")
        finally:
            os._exit(0)
    os.close(child_write)
    outcome = os.read(parent_read, 16)
    os.close(parent_read)
    os.waitpid(pid, 0)
    return outcome


def main():
    assert os.geteuid() == 0, "run with podman unshare"
    backup = load_backup()
    with tempfile.TemporaryDirectory(prefix="gak-backup-security-", dir="/tmp") as temporary:
        root = Path(temporary)
        root.chmod(0o711)
        runtime = root / "agent-runtime"
        runtime.mkdir(mode=0o700)
        os.chown(runtime, 1001, 1001)
        result_root = root / "root-results"
        result_root.mkdir(mode=0o700)
        restore_root = root / "root-restore"
        restore_root.mkdir(mode=0o700)
        secret_root = root / "outside"
        secret_root.mkdir(mode=0o700)
        sentinel = secret_root / "sentinel"
        sentinel.write_text("untouched")
        sentinel.chmod(0o600)
        backup.RUNTIME = runtime
        backup.RESULT_ROOT = result_root
        backup.agent_account = lambda: SimpleNamespace(pw_uid=1001, pw_gid=1001)

        # The agent swaps the published name after root has reserved its private file.
        original_fchown = os.fchown
        def swap_then_chown(descriptor, uid, gid):
            assert attacker(lambda: (runtime / "backup-result").symlink_to(sentinel)) == b"ok"
            return original_fchown(descriptor, uid, gid)
        backup.os.fchown = swap_then_chown
        try:
            backup.publish_result("123-456", "ok")
        finally:
            backup.os.fchown = original_fchown
        assert sentinel.read_text() == "untouched"
        assert stat.S_ISREG((runtime / "backup-result").lstat().st_mode)
        assert (runtime / "backup-result").read_text() == "ok 123-456\n"
        print("result symlink swap: outside sentinel untouched; atomic result published")

        request = runtime / "backup-request"
        os.mkfifo(request, 0o600)
        os.chown(request, 1001, 1001)
        try:
            backup.read_request()
        except RuntimeError as error:
            assert "unsafe backup file" in str(error)
        else:
            raise AssertionError("agent FIFO request was accepted")
        request.unlink()

        # The agent cannot rename or substitute a directory under the root parent.
        scratch = Path(tempfile.mkdtemp(prefix="restore.", dir=restore_root))
        replacement = runtime / "replacement"
        replacement.mkdir()
        (replacement / "source.sha256").symlink_to(sentinel)
        assert attacker(lambda: os.rename(scratch, scratch.with_name("moved"))) == b"denied"
        assert attacker(lambda: os.symlink(replacement, restore_root / "substitute")) == b"denied"
        assert scratch.is_dir() and sentinel.read_text() == "untouched"
        print("restore rename and symlink substitution: denied by root-owned parent")

        # A configured agent-owned scratch parent is refused before any restore write.
        backup.BACKUP_ROOT = runtime
        backup.REPOSITORY = runtime / "restic"
        backup.validate_password = lambda: None
        backup.subprocess.run = lambda *args, **kwargs: SimpleNamespace(returncode=0)
        try:
            backup.snapshot()
        except RuntimeError as error:
            assert "unsafe backup directory" in str(error)
        else:
            raise AssertionError("agent-owned restore parent was accepted")
        assert sentinel.read_text() == "untouched"
        print("agent-owned restore parent: job refused safely")


if __name__ == "__main__":
    main()
