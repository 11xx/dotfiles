#!/usr/bin/env python3
"""Exercise candidate isolation and the snapshot boundary of aiagent update."""

import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time


SOURCE = Path(__file__).resolve().parents[1] / "files/aiagent-update"
OLD = "a" * 64
NEW = "e" * 64
PODMAN = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["AIAGENT_UPDATE_TEST_ROOT"])
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["image", "inspect"]:
    if args[-1] == "localhost/aiagent-fedora:44-v1":
        print("%s" if not (root / "accepted").exists() else "%s")
    elif args[-1].startswith("localhost/gak-services-previous:"):
        assert (root / "pin-present").exists()
        print("%s")
    else:
        print("%s")
elif args[0] == "run":
    assert "--network" in args and args[args.index("--network") + 1] == "none"
    assert not any(arg in ("-v", "--volume", "--mount") for arg in args)
    if os.environ.get("BROKEN_PI_WRAPPER") and args[-1] == "/usr/local/bin/aiagent-readiness":
        sys.exit(3)
elif args[:2] == ["compose", "-f"] and "stop" in args:
    (root / "stopped").touch()
elif args[:2] == ["compose", "-f"] and "up" in args:
    (root / "stopped").unlink()
'''
UPDATER = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
root = Path(os.environ["AIAGENT_UPDATE_TEST_ROOT"])
assert (root / "stopped").exists()
(root / "updater-args").write_text(json.dumps(sys.argv[1:]))
if os.environ.get("FAIL_AFTER_APPLY"):
    (root / "pin-present").touch()
    sys.exit(1)
(root / "accepted").touch()
'''


def replace(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def exercise(root, broken=False, postapply=False):
    home = root / "home"
    (home / "image").mkdir(parents=True)
    (home / "image/Containerfile").write_text("FROM scratch\n")
    (home / "services/agent").mkdir(parents=True)
    (home / "services/agent/compose.yaml").write_text("name: agent\n")
    (home / "workspaces").mkdir()
    (home / "container-home").mkdir()
    (home / "workspaces/sentinel").write_text("workspace state")
    (home / "container-home/sentinel").write_text("login state")
    (home / ".guix-profile/bin").mkdir(parents=True)
    updater = home / ".guix-profile/bin/gak-services"
    updater.write_text(UPDATER)
    updater.chmod(0o755)
    fake = root / "podman"
    fake.write_text(PODMAN % (OLD, NEW, OLD, NEW))
    fake.chmod(0o755)
    source = SOURCE.read_text()
    source = replace(source, 'HOME = Path("/home/aiagent")', f"HOME = Path({str(home)!r})")
    source = replace(source, 'PODMAN = "/run/current-system/profile/bin/podman"', f"PODMAN = {str(fake)!r}")
    source = replace(source, 'REQUEST = Path("/run/aiagent/backup-request")', f"REQUEST = Path({str(root / 'request')!r})")
    source = replace(source, 'RESULT = Path("/run/aiagent/backup-result")', f"RESULT = Path({str(root / 'result')!r})")
    script = root / "aiagent-update"
    script.write_text(source)
    script.chmod(0o755)
    env = dict(os.environ, AIAGENT_UPDATE_TEST_ROOT=str(root))
    if broken:
        env["BROKEN_PI_WRAPPER"] = "1"
    if postapply:
        env["FAIL_AFTER_APPLY"] = "1"

    def answer_backup():
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if (root / "request").exists():
                assert (root / "stopped").exists()
                assert (home / "workspaces/sentinel").read_text() == "workspace state"
                assert (home / "container-home/sentinel").read_text() == "login state"
                nonce = (root / "request").read_text().strip()
                (root / "result").write_text(f"ok {nonce}\n")
                return
            time.sleep(0.02)
        raise AssertionError("backup was not requested")

    responder = None
    if not broken:
        responder = threading.Thread(target=answer_backup)
        responder.start()
    result = subprocess.run([script], env=env, capture_output=True, text=True, timeout=15)
    if responder:
        responder.join(timeout=10)
    assert result.returncode == (1 if broken or postapply else 0), result.stderr
    calls = (root / "calls").read_text().splitlines()
    assert all('"pull"' not in call for call in calls)
    assert any('"/usr/local/bin/aiagent-readiness"' in call for call in calls)
    assert (home / "workspaces/sentinel").read_text() == "workspace state"
    assert (home / "container-home/sentinel").read_text() == "login state"
    if broken:
        assert not (root / "stopped").exists()
        assert not (root / "updater-args").exists()
    elif postapply:
        assert (root / "stopped").exists()
        assert (root / "pin-present").exists()
        assert f"previous image {OLD[:12]} retained at localhost/gak-services-previous:" in result.stderr
        assert "GAK-SERVICES.org" in result.stderr
        assert not any('"up"' in call for call in calls)
    else:
        assert "--from-stopped" in (root / "updater-args").read_text()
        assert f"agent={NEW}" in (root / "updater-args").read_text()


def main():
    with tempfile.TemporaryDirectory(prefix="aiagent-update-", dir=Path.home() / ".cache") as scratch:
        root = Path(scratch)
        for name, broken, postapply in (("broken-pi", True, False),
                                        ("accepted", False, False),
                                        ("postapply-failure", False, True)):
            case = root / name
            case.mkdir()
            exercise(case, broken, postapply)
    print("missing Pi wrapper failed candidate readiness before stop; accepted update followed a snapshot")
    print("post-apply failure named the retained previous tag and manual rollback without auto rollback")


if __name__ == "__main__":
    main()
