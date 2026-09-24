#!/usr/bin/env python3
"""Exercise a hub bundle while receive-pack has quarantined a new branch."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
from types import SimpleNamespace


SOURCE = Path(os.environ.get(
    "BACKUP_SOURCE", Path(__file__).resolve().parents[1] / "files/modules/aiagent/backup.py"))
spec = importlib.util.spec_from_file_location("agent_backup", SOURCE)
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


def run(*args, **kwargs):
    return subprocess.run(args, check=True, stdout=subprocess.DEVNULL,
                          stderr=subprocess.PIPE, **kwargs)


def main():
    assert os.geteuid() == 0, "run with podman unshare"
    hub_uid = int(os.environ.get("GAK_TEST_HUB_UID", "1001"))
    scratch_parent = os.environ.get("GAK_HUB_TEST_ROOT", "/var/tmp")
    with tempfile.TemporaryDirectory(prefix="git-hub-backup.", dir=scratch_parent) as temporary:
        root = Path(temporary)
        root.chmod(0o711)
        backup.HUB_HOME = root / "hub"
        backup.HUB_HOME.mkdir(mode=0o750)
        repos = backup.HUB_HOME / "repositories"
        repos.mkdir()
        backup.BACKUP_ROOT = root / "backup"
        backup.BACKUP_ROOT.mkdir(mode=0o700)
        backup.hub_account = lambda: SimpleNamespace(pw_uid=hub_uid, pw_gid=hub_uid)
        source = root / "source"
        run("git", "init", "-q", str(source))
        run("git", "-C", str(source), "-c", "user.name=Test",
            "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "seed")
        for name in backup.HUB_REPOS:
            bare = repos / f"{name}.git"
            run("git", "init", "--bare", "-q", str(bare))
            run("git", "-C", str(source), "push", "-q", str(bare), "HEAD:refs/heads/main")

        marker = root / "receiving"
        release = root / "release"
        calls = root / "hook-calls"
        hook = repos / "arc.git/hooks/pre-receive"
        hook.write_text(f"#!/bin/sh\necho called >> '{calls}'\ntouch '{marker}'\nwhile [ ! -f '{release}' ]; do sleep .1; done\n")
        hook.chmod(0o755)
        run("git", "-C", str(source), "checkout", "-qb", "pending")
        run("git", "-C", str(source), "-c", "user.name=Test",
            "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "pending")
        push = subprocess.Popen(("git", "-C", str(source), "push", str(repos / "arc.git"),
                                 "HEAD:refs/heads/agent/pending"),
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            for _ in range(100):
                if marker.exists():
                    break
                time.sleep(0.05)
            assert marker.exists(), "push did not reach pre-receive"
            for directory, dirs, files in os.walk(backup.HUB_HOME):
                for name in dirs + files:
                    os.chown(Path(directory) / name, hub_uid, hub_uid)
            os.chown(backup.HUB_HOME, hub_uid, hub_uid)
            read_fd, write_fd = os.pipe()
            child = os.fork()
            if child == 0:
                os.close(read_fd)
                os.setgroups([])
                os.setgid(1002)
                os.setuid(1002)
                try:
                    os.listdir(backup.HUB_HOME)
                    os.write(write_fd, b"readable")
                except PermissionError:
                    os.write(write_fd, b"denied")
                os._exit(0)
            os.close(write_fd)
            assert os.read(read_fd, 16) == b"denied"
            os.close(read_fd)
            os.waitpid(child, 0)
            bundles, hashes = backup.hub_bundles()
            assert set(hashes) == set(backup.HUB_REPOS)
            assert all((bundles / f"{name}.bundle").stat().st_uid == 0 for name in hashes)
            heads = subprocess.check_output(("git", "bundle", "list-heads",
                                             str(bundles / "arc.bundle")), text=True)
            assert "refs/heads/main" in heads
            assert "refs/heads/agent/pending" not in heads
            assert calls.read_text().splitlines() == ["called"]
            backup.verify_bundles(bundles, hashes)
            print("in-flight push excluded; both bundles are complete and root-owned")
            print("root backup did not execute the repository pre-receive hook")
            print("agent UID cannot read the hub home")
        finally:
            release.touch()
            assert push.wait(timeout=10) == 0, push.stderr.read().decode()

        if os.environ.get("GAK_TEST_RESTIC"):
            assert shutil.which("restic"), "restic is unavailable"
            backup.HOME = root / "agent"
            for name in ("workspaces", "container-home"):
                directory = backup.HOME / name
                directory.mkdir(parents=True)
                (directory / "sentinel").write_text(name)
            backup.REPOSITORY = backup.BACKUP_ROOT / "restic"
            backup.PASSWORD = root / "password"
            backup.PASSWORD.write_text("isolated-test-password\n")
            backup.PASSWORD.chmod(0o600)
            original_run = backup.run_process

            def mounted(arguments, **kwargs):
                if arguments[0] == "findmnt":
                    return subprocess.CompletedProcess(arguments, 0)
                return original_run(arguments, **kwargs)

            backup.run_process = mounted
            try:
                backup.restore_check()
            finally:
                backup.run_process = original_run


if __name__ == "__main__":
    main()
