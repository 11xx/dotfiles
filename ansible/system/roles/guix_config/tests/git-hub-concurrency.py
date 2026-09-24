#!/usr/bin/env python3
"""Prove Gitolite receive and the complete multi-repo backup share a lock."""

from contextlib import contextmanager
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from types import SimpleNamespace


ROOT = Path(os.environ.get("GAK_HUB_FIXTURE_ROOT", "/var/tmp"))
HUB = ROOT / "hub"
LOCK = Path("/var/lib/agentgit-lock")
UID = 1001
SOURCE = Path(os.environ.get(
    "BACKUP_SOURCE", Path(__file__).resolve().parents[1] / "files/modules/aiagent/backup.py"))
spec = importlib.util.spec_from_file_location("agent_backup", SOURCE)
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


def run(args, *, as_hub=False, env=None, check=True, **kwargs):
    options = {"stdout": subprocess.PIPE, "stderr": subprocess.PIPE, "text": True,
               "env": env, **kwargs}
    if as_hub:
        options.update(user=UID, group=UID, extra_groups=[])
    result = subprocess.run(args, **options)
    if check and result.returncode:
        raise RuntimeError(f"command failed: {args[0]} {args[1:3]}: {result.stderr[-600:]}")
    return result


def wait_for(path):
    for _ in range(200):
        if path.exists():
            return
        time.sleep(0.05)
    raise RuntimeError(f"timed out waiting for {path.name}")


def setup():
    ROOT.mkdir(mode=0o711)
    ROOT.chmod(0o711)
    HUB.mkdir(mode=0o750)
    os.chown(HUB, UID, UID)
    LOCK.mkdir(mode=0o750)
    os.chown(LOCK, 0, UID)
    lock_file = LOCK / "receive.lock"
    lock_file.touch(mode=0o660)
    os.chown(lock_file, 0, UID)
    lock_file.chmod(0o660)

    code = ROOT / "local-code/lib/Gitolite/Triggers"
    code.mkdir(parents=True)
    shutil.copyfile(os.environ["HUB_LOCK_SOURCE"], code / "HubLock.pm")
    rc = Path(os.environ["GENERATED_RC"]).read_text()
    assert 'LOCAL_CODE => "/etc/git-hub"' in rc
    assert "PRE_GIT => ['HubLock::pre_git']" in rc
    assert "POST_GIT => ['HubLock::post_git']" in rc
    if os.environ.get("GAK_TEST_DISABLE_RECEIVE_LOCK"):
        rc = rc.replace("    PRE_GIT => ['HubLock::pre_git'],\n", "")
        rc = rc.replace("    POST_GIT => ['HubLock::post_git'],\n", "")
    (HUB / ".gitolite.rc").write_text(
        rc.replace('LOCAL_CODE => "/etc/git-hub"',
                   f'LOCAL_CODE => "{ROOT / "local-code"}"'))
    shutil.copyfile(os.environ["GENERATED_GITCONFIG"], HUB / ".gitconfig")
    assert "maxInputSize = 33554432" in (HUB / ".gitconfig").read_text()
    for path in (HUB / ".gitolite.rc", HUB / ".gitconfig"):
        os.chown(path, UID, UID)

    run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(ROOT / "operator")])
    run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(ROOT / "aiagent")])
    package_bin = Path(os.environ["GITOLITE_BIN"]).parent
    environment = dict(os.environ, HOME=str(HUB), USER="agentgit",
                       PATH=f"{package_bin}:/run/current-system/profile/bin:/usr/bin:/bin")
    run([os.environ["GITOLITE_BIN"], "setup", "-pk", str(ROOT / "operator.pub")],
        as_hub=True, env=environment, cwd=HUB)

    wrapper = ROOT / "ssh-wrapper"
    wrapper.write_text("#!/bin/sh\nshift\nexport SSH_CONNECTION='127.0.0.1 1 127.0.0.1 2'\n"
                       "export SSH_ORIGINAL_COMMAND=\"$*\"\n"
                       "exec \"$GITOLITE_SHELL\" \"$GITOLITE_ID\"\n")
    wrapper.chmod(0o755)
    client = dict(environment, GIT_SSH=str(wrapper),
                  GITOLITE_SHELL=os.environ["GITOLITE_SHELL"])
    admin_work = ROOT / "admin-work"
    admin_work.mkdir(mode=0o700)
    os.chown(admin_work, UID, UID)
    run(["git", "clone", "-q", "dummy:gitolite-admin", str(admin_work)],
        as_hub=True, env=dict(client, GITOLITE_ID="operator"))
    admin_policy = admin_work / "conf/gitolite.conf"
    admin_policy.write_text(Path(os.environ["POLICY_SOURCE"]).read_text())
    agent_key = admin_work / "keydir/aiagent.pub"
    shutil.copyfile(ROOT / "aiagent.pub", agent_key)
    os.chown(admin_policy, UID, UID)
    os.chown(agent_key, UID, UID)
    run(["git", "-C", str(admin_work), "add", "conf/gitolite.conf", "keydir/aiagent.pub"],
        as_hub=True, env=client)
    run(["git", "-C", str(admin_work), "-c", "user.name=Test", "-c",
         "user.email=test@example.invalid", "commit", "-qm", "policy"],
        as_hub=True, env=client)
    run(["git", "-C", str(admin_work), "push", "dummy:gitolite-admin", "HEAD"],
        as_hub=True, env=dict(client, GITOLITE_ID="operator"))
    work = ROOT / "arc-work"
    work.mkdir(mode=0o700)
    os.chown(work, UID, UID)
    run(["git", "init", "-q", "-b", "main", str(work)], as_hub=True, env=client)
    (work / "README").write_text("seed\n")
    os.chown(work / "README", UID, UID)
    run(["git", "-C", str(work), "add", "README"], as_hub=True, env=client)
    run(["git", "-C", str(work), "-c", "user.name=Test", "-c",
         "user.email=test@example.invalid", "commit", "-qm", "seed"],
        as_hub=True, env=client)
    run(["git", "-C", str(work), "push", "dummy:arc", "HEAD:refs/heads/main"],
        as_hub=True, env=dict(client, GITOLITE_ID="operator"))
    admin_policy.write_text(admin_policy.read_text() + "\n# retained policy revision\n")
    os.chown(admin_policy, UID, UID)
    run(["git", "-C", str(admin_work), "add", "conf/gitolite.conf"],
        as_hub=True, env=client)
    run(["git", "-C", str(admin_work), "-c", "user.name=Test", "-c",
         "user.email=test@example.invalid", "commit", "-qm", "policy"],
        as_hub=True, env=client)
    run(["git", "-C", str(work), "checkout", "-qb", "agent/update"],
        as_hub=True, env=client)
    (work / "fix").write_text("agent change\n")
    os.chown(work / "fix", UID, UID)
    run(["git", "-C", str(work), "add", "fix"], as_hub=True, env=client)
    run(["git", "-C", str(work), "-c", "user.name=Test", "-c",
         "user.email=test@example.invalid", "commit", "-qm", "fix"],
        as_hub=True, env=client)
    return environment, client, work, admin_work


def main():
    assert os.geteuid() == 0, "run with podman unshare"
    environment, client, work, admin_work = setup()
    backup.HUB_HOME = HUB
    backup.hub_account = lambda: SimpleNamespace(pw_uid=UID, pw_gid=UID)
    backup.HOME = ROOT / "agent"
    for name in ("workspaces", "container-home"):
        directory = backup.HOME / name
        directory.mkdir(parents=True)
        (directory / "sentinel").write_text(name)
    backup.BACKUP_ROOT = ROOT / "backup"
    backup.BACKUP_ROOT.mkdir(mode=0o700)
    backup.REPOSITORY = backup.BACKUP_ROOT / "restic"
    backup.PASSWORD = ROOT / "password"
    backup.PASSWORD.write_text("isolated-test-password\n")
    backup.PASSWORD.chmod(0o600)
    paused = ROOT / "after-admin-bundle"
    resume = ROOT / "resume-bundles"
    at_restic = ROOT / "at-restic-backup"
    finish = ROOT / "finish-restic-backup"
    evidence = ROOT / "evidence"
    evidence.mkdir(mode=0o700)
    old_admin = run(["git", "-C", str(HUB / "repositories/gitolite-admin.git"),
                     "rev-parse", "refs/heads/master"], as_hub=True,
                    env=environment).stdout.strip()
    child = os.fork()
    if child == 0:
        original = backup.run_process

        def controlled(arguments, **kwargs):
            if arguments[0] == "findmnt":
                return subprocess.CompletedProcess(arguments, 0)
            if arguments[0] == "restic":
                if "backup" in arguments:
                    for path in arguments:
                        if str(path).startswith(str(backup.BACKUP_ROOT / "hub-bundles.")):
                            for artifact in Path(path).iterdir():
                                if artifact.is_file():
                                    shutil.copyfile(artifact, evidence / artifact.name)
                    at_restic.touch()
                    wait_for(finish)
                return subprocess.CompletedProcess(arguments, 0)
            result = original(arguments, **kwargs)
            if (len(arguments) >= 6 and arguments[0] == "git"
                    and "gitolite-admin.git" in str(arguments)
                    and arguments[-4:] == ("bundle", "create", "-", "--all")):
                paused.touch()
                wait_for(resume)
            return result

        backup.run_process = controlled
        if os.environ.get("GAK_TEST_DISABLE_BACKUP_LOCK"):
            @contextmanager
            def no_lock():
                yield
            backup.hub_exclusion = no_lock
        try:
            _, _, expected = backup.snapshot()
            (ROOT / "expected.json").write_text(json.dumps(expected))
            os._exit(0)
        except BaseException as error:
            (ROOT / "backup-error").write_text(repr(error))
            os._exit(1)

    pushes = []
    try:
        wait_for(paused)
        for args, identity in [
            (["git", "-C", str(admin_work), "push", "dummy:gitolite-admin", "HEAD"], "operator"),
            (["git", "-C", str(work), "push", "dummy:arc",
              "HEAD:refs/heads/agent/update"], "aiagent"),
        ]:
            pushes.append(subprocess.Popen(args, user=UID, group=UID,
                                           extra_groups=[], env=dict(client, GITOLITE_ID=identity),
                                           stdout=subprocess.DEVNULL,
                                           stderr=subprocess.PIPE))
        time.sleep(1)
        assert all(process.poll() is None for process in pushes), "receive passed the backup lock"
        resume.touch()
        try:
            wait_for(at_restic)
        except RuntimeError:
            if (ROOT / "backup-error").exists():
                raise RuntimeError((ROOT / "backup-error").read_text()) from None
            raise
        time.sleep(1)
        assert all(process.poll() is None for process in pushes), "receive passed the Restic boundary"
    finally:
        resume.touch()
        finish.touch()
    assert os.waitpid(child, 0)[1] == 0, (ROOT / "backup-error").read_text()
    for process in pushes:
        assert process.wait(timeout=30) == 0, process.stderr.read().decode()[-600:]
    expected = json.loads((ROOT / "expected.json").read_text())
    assert json.loads((evidence / "manifest.json").read_text()) == expected
    assert expected["repos"]["gitolite-admin"]["refs"]["refs/heads/master"] == old_admin
    assert "refs/heads/agent/update" not in expected["repos"]["arc"]["refs"]
    current_admin = run(["git", "-C", str(HUB / "repositories/gitolite-admin.git"),
                         "rev-parse", "refs/heads/master"], as_hub=True,
                        env=environment).stdout.strip()
    assert current_admin != old_admin
    assert run(["git", "-C", str(HUB / "repositories/arc.git"),
                "show-ref", "--verify", "refs/heads/agent/update"],
               as_hub=True, env=environment).returncode == 0
    expected["admin_files"] = {name: tuple(value)
                               for name, value in expected["admin_files"].items()}
    backup.verify_bundles(evidence, expected["repos"], expected["admin_files"],
                          backup.hub_account())
    print("Gitolite admin and Arc receives waited through both repository bundles and Restic backup")
    print("captured old policy and old Arc refs; both pushes completed after release")

    large = work / "large.bin"
    large.write_bytes(os.urandom(34 * 1024 * 1024))
    os.chown(large, UID, UID)
    run(["git", "-C", str(work), "add", "large.bin"], as_hub=True, env=client)
    run(["git", "-C", str(work), "-c", "user.name=Test", "-c",
         "user.email=test@example.invalid", "commit", "-qm", "large"],
        as_hub=True, env=client)
    oversized = run(["git", "-C", str(work), "push", "dummy:arc",
                     "HEAD:refs/heads/agent/oversize"], as_hub=True,
                    env=dict(client, GITOLITE_ID="aiagent"), check=False)
    assert oversized.returncode and "pack exceeds maximum allowed size" in oversized.stderr
    missing = run(["git", "-C", str(HUB / "repositories/arc.git"),
                   "show-ref", "--verify", "refs/heads/agent/oversize"],
                  as_hub=True, env=environment, check=False)
    assert missing.returncode != 0
    print("generated Git configuration rejected an oversized Gitolite push without a ref")


if __name__ == "__main__":
    main()
