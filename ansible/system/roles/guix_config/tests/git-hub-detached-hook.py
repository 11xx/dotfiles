#!/usr/bin/env python3
"""A detached hook child must not retain the completed receive lock."""

import fcntl
import importlib.util
import os
from pathlib import Path
import shlex
import signal
import subprocess
import sys
import time


FIXTURE = Path(os.environ.get(
    "CONCURRENCY_SOURCE", Path(__file__).with_name("git-hub-concurrency.py")))
spec = importlib.util.spec_from_file_location("hub_fixture", FIXTURE)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


def main():
    _, client, work, _ = fixture.setup()
    repository = fixture.HUB / "repositories/arc.git"
    hook = repository / "hooks/pre-receive"
    saved = hook.with_name("pre-receive.saved")
    if hook.exists() or hook.is_symlink():
        hook.rename(saved)
    pid_file = fixture.HUB / "detached.pid"
    daemon = "\n".join((
        "import os, time",
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
        "time.sleep(15)",
    ))
    hook.write_text("#!/bin/sh\n"
                    f"{shlex.quote(os.path.realpath(sys.executable))} -c {shlex.quote(daemon)}\n"
                    f"if [ -x '{saved}' ]; then exec '{saved}'; fi\n")
    hook.chmod(0o755)
    os.chown(hook, fixture.UID, fixture.UID)
    detached = None
    try:
        push = subprocess.run(["git", "-C", str(work), "push", "dummy:arc",
                               "HEAD:refs/heads/agent/detached"],
                              user=fixture.UID, group=fixture.UID, extra_groups=[],
                              env=dict(client, GITOLITE_ID="aiagent"),
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                              text=True, timeout=20)
        assert push.returncode == 0, push.stderr[-500:]
        fixture.wait_for(pid_file)
        detached = int(pid_file.read_text())
        os.kill(detached, 0)
        descriptor = os.open(fixture.LOCK / "receive.lock", os.O_RDWR | os.O_NOFOLLOW)
        try:
            deadline = time.monotonic() + 0.8
            while True:
                try:
                    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise AssertionError("detached hook retained completed receive lock") from None
                    time.sleep(0.05)
        finally:
            os.close(descriptor)
        lock = (fixture.LOCK / "receive.lock").stat()
        for entry in Path(f"/proc/{detached}/fd").iterdir():
            try:
                held = entry.stat()
            except FileNotFoundError:
                continue
            assert (held.st_dev, held.st_ino) != (lock.st_dev, lock.st_ino)
        print("completed receive released lock while detached hook child remained alive")
    finally:
        if detached is not None:
            try:
                os.kill(detached, signal.SIGTERM)
            except ProcessLookupError:
                pass


if __name__ == "__main__":
    main()
