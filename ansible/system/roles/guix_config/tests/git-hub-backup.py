#!/usr/bin/env python3
"""Exercise bundle integrity and recovery during a quarantined push."""

import importlib.util
import json
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
        (source / "conf").mkdir()
        (source / "keydir").mkdir()
        (source / "conf/gitolite.conf").write_text("repo arc\n    RW+ = operator\n")
        (source / "keydir/operator.pub").write_text("test operator key\n")
        (source / "keydir/aiagent.pub").write_text("test agent key\n")
        run("git", "-C", str(source), "add", "conf", "keydir")
        run("git", "-C", str(source), "-c", "user.name=Test",
            "-c", "user.email=test@example.invalid", "commit", "-qm", "seed")
        admin = backup.HUB_HOME / ".gitolite"
        shutil.copytree(source / "conf", admin / "conf")
        shutil.copytree(source / "keydir", admin / "keydir")
        for name in backup.HUB_REPOS:
            bare = repos / f"{name}.git"
            branch = "master" if name == "gitolite-admin" else "main"
            run("git", "init", "--bare", "-q", "-b", branch, str(bare))
            run("git", "-C", str(source), "push", "-q", str(bare), f"HEAD:refs/heads/{branch}")

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
            lock_directory = root / "hub-lock"
            lock_directory.mkdir(mode=0o750)
            os.chown(lock_directory, 0, hub_uid)
            lock_file = lock_directory / "receive.lock"
            lock_file.touch(mode=0o660)
            os.chown(lock_file, 0, hub_uid)
            lock_file.chmod(0o660)
            backup.HUB_LOCK_DIRECTORY = lock_directory
            backup.HUB_LOCK = lock_file
            if hub_uid != 0:
                read_fd, write_fd = os.pipe()
                child = os.fork()
                if child == 0:
                    os.close(read_fd)
                    os.setgroups([])
                    os.setgid(hub_uid)
                    os.setuid(hub_uid)
                    try:
                        lock_file.rename(lock_file.with_name("replacement"))
                        os.write(write_fd, b"replaced")
                    except PermissionError:
                        os.write(write_fd, b"denied")
                    os._exit(0)
                os.close(write_fd)
                assert os.read(read_fd, 16) == b"denied"
                os.close(read_fd)
                os.waitpid(child, 0)
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
            with backup.hub_exclusion():
                bundles, expected = backup.hub_bundles()
            assert set(expected["repos"]) == set(backup.HUB_REPOS)
            assert json.loads((bundles / "manifest.json").read_text()) == json.loads(json.dumps(expected))
            assert all((bundles / f"{name}.bundle").stat().st_uid == 0 for name in expected["repos"])
            heads = subprocess.check_output(("git", "bundle", "list-heads",
                                             str(bundles / "arc.bundle")), text=True)
            assert "refs/heads/main" in heads
            assert "refs/heads/agent/pending" not in heads
            assert calls.read_text().splitlines() == ["called"]
            bundle = bundles / "arc.bundle"
            content = bundle.read_bytes()
            bundle.write_bytes(content[:content.index(b"PACK")])
            try:
                backup.verify_bundles(bundles, expected["repos"],
                                      expected["admin_files"], backup.hub_account())
            except (RuntimeError, subprocess.CalledProcessError):
                pass
            else:
                raise AssertionError("a truncated bundle was accepted")
            bundle.write_bytes(content)
            backup.verify_bundles(bundles, expected["repos"],
                                  expected["admin_files"], backup.hub_account())
            print("quarantined ref omitted; both bundles are complete and root-owned")
            print("root backup did not execute the repository pre-receive hook")
            print("agent UID cannot read the hub home")
            if hub_uid != 0:
                print("hub UID cannot replace the root-owned lock")
            print("truncated bundle rejected; refs, policy and keys reconstructed")
        finally:
            release.touch()
            assert push.wait(timeout=10) == 0, push.stderr.read().decode()

        if os.environ.get("GAK_TEST_RESTIC"):
            assert shutil.which("restic"), "restic is unavailable"
            os.environ["TMPDIR"] = str(root)
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
