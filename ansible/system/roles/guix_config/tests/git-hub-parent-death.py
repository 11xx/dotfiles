#!/usr/bin/env python3
"""Keep backup excluded when Gitolite dies during a project or admin receive."""

import fcntl
import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from types import SimpleNamespace


FIXTURE = Path(os.environ.get(
    "CONCURRENCY_SOURCE", Path(__file__).with_name("git-hub-concurrency.py")))
spec = importlib.util.spec_from_file_location("hub_fixture", FIXTURE)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


def wait_for(path):
    for _ in range(200):
        if path.exists():
            return
        time.sleep(0.05)
    raise RuntimeError(f"timed out waiting for {path.name}")


def ref_exists(repository, ref, environment):
    result = fixture.run(["git", "-C", str(repository), "show-ref", "--verify", ref],
                         as_hub=True, env=environment, check=False)
    return result.returncode == 0


def main(target):
    assert target in ("project", "admin")
    environment, client, work, admin_work = fixture.setup()
    backup = fixture.backup
    backup.HUB_HOME = fixture.HUB
    backup.hub_account = lambda: SimpleNamespace(pw_uid=fixture.UID, pw_gid=fixture.UID)
    repository = fixture.HUB / "repositories" / ("arc.git" if target == "project" else "gitolite-admin.git")
    ref = "refs/heads/agent/crash" if target == "project" else "refs/heads/master"
    old = fixture.run(["git", "-C", str(repository), "rev-parse", ref],
                      as_hub=True, env=environment, check=False).stdout.strip()

    pid_file = fixture.HUB / "gitolite-parent.pid"
    wrapper = fixture.ROOT / "ssh-wrapper"
    wrapper.write_text("#!/bin/sh\nshift\nexport SSH_CONNECTION='127.0.0.1 1 127.0.0.1 2'\n"
                       "export SSH_ORIGINAL_COMMAND=\"$*\"\n"
                       "printf '%s\\n' \"$$\" > \"$GAK_PARENT_PID_FILE\"\n"
                       "exec \"$GITOLITE_SHELL\" \"$GITOLITE_ID\"\n")
    wrapper.chmod(0o755)
    client = dict(client, GAK_PARENT_PID_FILE=str(pid_file))

    ready = fixture.HUB / "hook-ready"
    release = fixture.HUB / "hook-release"
    hook = repository / "hooks/pre-receive"
    saved = hook.with_name("pre-receive.saved")
    if hook.exists() or hook.is_symlink():
        hook.rename(saved)
    hook.write_text(f"#!/bin/sh\ntouch '{ready}'\n"
                    f"while [ ! -e '{release}' ]; do sleep .05; done\n"
                    f"if [ -x '{saved}' ]; then exec '{saved}'; fi\n")
    hook.chmod(0o755)
    os.chown(hook, fixture.UID, fixture.UID)

    if target == "project":
        args = ["git", "-C", str(work), "push", "dummy:arc",
                "HEAD:refs/heads/agent/crash"]
        identity = "aiagent"
    else:
        args = ["git", "-C", str(admin_work), "push", "dummy:gitolite-admin", "HEAD"]
        identity = "operator"
    push = subprocess.Popen(args, user=fixture.UID, group=fixture.UID,
                            extra_groups=[], env=dict(client, GITOLITE_ID=identity),
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    waiter = None
    acquired = fixture.ROOT / "backup-acquired"
    try:
        wait_for(ready)
        wait_for(pid_file)
        descriptor = os.open(fixture.LOCK / "receive.lock", os.O_RDWR | os.O_NOFOLLOW)
        try:
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                pass
            else:
                raise AssertionError("receive did not acquire the lock")
        finally:
            os.close(descriptor)

        os.kill(int(pid_file.read_text()), signal.SIGKILL)
        waiter = os.fork()
        if waiter == 0:
            try:
                with backup.hub_exclusion():
                    acquired.touch()
                os._exit(0)
            except BaseException as error:
                (fixture.ROOT / "backup-error").write_text(repr(error))
                os._exit(1)
        time.sleep(0.5)
        assert not acquired.exists(), "backup entered while orphaned receive was paused"
        release.touch()
        wait_for(acquired)
        if target == "project":
            assert ref_exists(repository, ref, environment)
        else:
            current = fixture.run(["git", "-C", str(repository), "rev-parse", ref],
                                  as_hub=True, env=environment).stdout.strip()
            assert current != old
            assert "# retained policy revision" in (
                fixture.HUB / ".gitolite/conf/gitolite.conf").read_text()
        assert os.waitpid(waiter, 0)[1] == 0
        waiter = None
        print(f"{target} receive retained exclusion after Gitolite parent SIGKILL until writes settled")
    finally:
        release.touch()
        if waiter is not None:
            os.waitpid(waiter, 0)
        push.wait(timeout=20)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) == 2 else "")
