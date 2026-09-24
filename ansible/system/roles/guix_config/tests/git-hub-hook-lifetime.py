#!/usr/bin/env python3
"""An original hook descendant retains exclusion until its last write."""

import importlib.util
import os
from pathlib import Path
import shlex
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


def daemon_program(pid_file, ready, release, complete, mutation):
    return "\n".join((
        "import os, subprocess, time",
        "if os.fork(): os._exit(0)",
        "os.setsid()",
        "null = os.open('/dev/null', os.O_RDWR)",
        "for stream in (0, 1, 2): os.dup2(null, stream)",
        "if null > 2: os.close(null)",
        f"open('{pid_file}', 'w').write(str(os.getpid()))",
        "lock = os.stat('/var/lib/agentgit-lock/receive.lock')",
        "for name in os.listdir('/proc/self/fd'):",
        "    fd = int(name)",
        "    if fd < 3: continue",
        "    try: held = os.fstat(fd)",
        "    except OSError: continue",
        "    if (held.st_dev, held.st_ino) != (lock.st_dev, lock.st_ino): os.close(fd)",
        f"open('{ready}', 'w').close()",
        f"while not os.path.exists('{release}'): time.sleep(0.05)",
        mutation,
        f"open('{complete}', 'w').close()",
    ))


def main(target):
    assert target in ("project", "admin")
    environment, client, work, admin_work = fixture.setup()
    backup = fixture.backup
    backup.HUB_HOME = fixture.HUB
    backup.hub_account = lambda: SimpleNamespace(pw_uid=fixture.UID, pw_gid=fixture.UID)
    repository = fixture.HUB / "repositories" / (
        "arc.git" if target == "project" else "gitolite-admin.git")
    hook_name = "post-receive" if target == "project" else "post-update"
    hook = repository / "hooks" / hook_name
    saved = hook.with_name(f"{hook_name}.saved")
    if hook.exists() or hook.is_symlink():
        hook.rename(saved)

    pid_file = fixture.HUB / "late-hook.pid"
    ready = fixture.HUB / "late-hook-ready"
    release = fixture.HUB / "late-hook-release"
    complete = fixture.HUB / "late-hook-complete"
    acquired = fixture.ROOT / "backup-acquired"
    if target == "project":
        oid = fixture.run(["git", "-C", str(work), "rev-parse", "HEAD"],
                          as_hub=True, env=environment).stdout.strip()
        mutation = ("subprocess.run(['git', '-C', "
                    f"'{repository}', 'update-ref', 'refs/heads/hook-late', '{oid}'], "
                    "check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)")
        push_args = ["git", "-C", str(work), "push", "dummy:arc",
                     "HEAD:refs/heads/agent/hook-late"]
        identity = "aiagent"
    else:
        policy = fixture.HUB / ".gitolite/conf/gitolite.conf"
        mutation = f"open('{policy}', 'a').write('\\n# late hook update\\n')"
        push_args = ["git", "-C", str(admin_work), "push", "dummy:gitolite-admin", "HEAD"]
        identity = "operator"
    program = daemon_program(pid_file, ready, release, complete, mutation)
    hook.write_text("#!/bin/sh\n"
                    f"{shlex.quote(os.path.realpath(sys.executable))} -c {shlex.quote(program)}\n"
                    f"if [ -x '{saved}' ]; then exec '{saved}' \"$@\"; fi\n")
    hook.chmod(0o755)
    os.chown(hook, fixture.UID, fixture.UID)

    descendant = None
    waiter = None
    try:
        push = subprocess.run(push_args, user=fixture.UID, group=fixture.UID,
                              extra_groups=[], env=dict(client, GITOLITE_ID=identity),
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                              text=True, timeout=20)
        assert push.returncode == 0, push.stderr[-600:]
        fixture.wait_for(ready)
        descendant = int(pid_file.read_text())
        os.kill(descendant, 0)

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
        assert not acquired.exists(), "backup entered before hook descendant completed"
        release.touch()
        fixture.wait_for(complete)
        fixture.wait_for(acquired)
        assert os.waitpid(waiter, 0)[1] == 0
        waiter = None
        if target == "project":
            result = fixture.run(["git", "-C", str(repository), "rev-parse",
                                  "refs/heads/hook-late"], as_hub=True,
                                 env=environment)
            assert result.stdout.strip() == oid
        else:
            assert "# late hook update" in (
                fixture.HUB / ".gitolite/conf/gitolite.conf").read_text()
        print(f"{target} hook descendant finished its state write before backup acquired")
    finally:
        release.touch()
        if waiter is not None:
            os.waitpid(waiter, 0)
        if descendant is not None:
            try:
                os.kill(descendant, signal.SIGTERM)
            except ProcessLookupError:
                pass


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) == 2 else "")
