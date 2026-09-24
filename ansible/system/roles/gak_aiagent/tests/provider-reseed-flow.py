#!/usr/bin/env python3
"""Exercise serialized provider repair across stop, backup, isolated reseed and restart."""

import importlib.machinery
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time


ROLE = Path(__file__).resolve().parents[1]
SOURCE = ROLE / "files/aiagent-update"
MANAGER_SOURCE = ROLE / "files/image/bin/aiagent-provider-prefix"
fixture = importlib.machinery.SourceFileLoader(
    "provider_prefix_fixture", str(ROLE / "tests/provider-prefix.py")
).load_module()
PODMAN = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path(os.environ["PROVIDER_RESEED_TEST_ROOT"])
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps(args) + "\\n")
if args[:2] == ["image", "inspect"]:
    print("a" * 64)
elif args[0] == "compose" and "stop" in args:
    (root / "stopped").touch()
    if os.environ.get("FAIL_STOP"):
        print("stop failed after partial quiescence", file=sys.stderr)
        sys.exit(42)
elif args[0] == "compose" and "up" in args:
    state = subprocess.run([os.environ["PROVIDER_RESEED_MANAGER"], "check"],
                           capture_output=True)
    if state.returncode == 0:
        (root / "ready").touch()
elif args[0] == "run":
    assert "--rm" in args and "--network" in args and args[args.index("--network") + 1] == "none"
    assert "--pull" in args and args[args.index("--pull") + 1] == "never"
    assert "--userns" in args and args[args.index("--userns") + 1] == "keep-id"
    assert args[args.index("--entrypoint") + 1] == "/usr/local/bin/aiagent-provider-prefix"
    assert args[-2] == "a" * 64
    assert args[-1] == "reseed"
    mounts = [arg for arg in args if arg.startswith("type=bind,")]
    assert len(mounts) == 1 and "/container-home,dst=/home/node,rw" in mounts[0]
    assert "/work" not in mounts[0] and "/cache" not in mounts[0]
    if os.environ.get("FAIL_RESEED"):
        print("synthetic reseed failure", file=sys.stderr)
        sys.exit(43)
    result = subprocess.run([os.environ["PROVIDER_RESEED_MANAGER"], "reseed"],
                            capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    sys.exit(result.returncode)
elif args[0] == "exec":
    if not (root / "ready").exists():
        print("agent is not ready", file=sys.stderr)
        sys.exit(1)
elif args[:2] == ["rm", "-f"]:
    (root / "disposable-cleanup").touch()
'''


def replace_one(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def exercise(root, mode):
    root.mkdir()
    home = root / "home"
    (home / "container-home").mkdir(parents=True)
    (home / "services/agent").mkdir(parents=True)
    (home / "services/agent/compose.yaml").write_text("name: agent\n")
    mounted = home / "container-home"
    credential = mounted / ".config/auth.json"
    credential.parent.mkdir()
    credential.write_text("synthetic login state")
    seed = root / "seed"
    (seed / "lib/node_modules").mkdir(parents=True)
    (seed / "bin").mkdir()
    for name, bins in fixture.PACKAGES.items():
        fixture.write_package(seed, name, bins, "1.0.0")
    manager_source = MANAGER_SOURCE.read_text()
    manager_source = replace_one(manager_source, 'HOME = Path("/home/node")',
                                 f"HOME = Path({str(mounted)!r})")
    manager_source = replace_one(manager_source, 'SEED = Path("/opt/aiagent-provider-seed")',
                                 f"SEED = Path({str(seed)!r})")
    manager = root / "provider-prefix"
    manager.write_text(manager_source)
    manager.chmod(0o755)
    assert subprocess.run([manager, "ensure"]).returncode == 0
    prefix = mounted / ".local/aiagent/npm"
    fixture.write_package(prefix, "@openai/codex", {"codex": "bin/codex.js"}, "9.9.9")
    if mode != "stop-failure":
        (prefix / "bin/ncu").unlink()
        assert subprocess.run([manager, "check"], capture_output=True).returncode != 0

    fake = root / "podman"
    fake.write_text(PODMAN)
    fake.chmod(0o755)
    source = SOURCE.read_text()
    source = replace_one(source, 'HOME = Path("/home/aiagent")', f"HOME = Path({str(home)!r})")
    source = replace_one(source, 'PODMAN = "/run/current-system/profile/bin/podman"',
                         f"PODMAN = {str(fake)!r}")
    source = replace_one(source, 'REQUEST = Path("/run/aiagent/backup-request")',
                         f"REQUEST = Path({str(root / 'request')!r})")
    source = replace_one(source, 'RESULT = Path("/run/aiagent/backup-result")',
                         f"RESULT = Path({str(root / 'result')!r})")
    source = replace_one(source, "await_agent_ready(30)", "await_agent_ready(1)")
    source = source.replace("time.sleep(2)", "time.sleep(0.1)")
    updater = root / "aiagent-update"
    updater.write_text(source)
    updater.chmod(0o755)
    env = dict(os.environ, PROVIDER_RESEED_TEST_ROOT=str(root),
               PROVIDER_RESEED_MANAGER=str(manager))
    if mode == "stop-failure":
        env["FAIL_STOP"] = "1"
    if mode == "reseed-failure":
        env["FAIL_RESEED"] = "1"

    def answer_backup():
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            request = root / "request"
            if request.exists():
                assert (root / "stopped").exists()
                nonce = request.read_text().strip()
                (root / "result").write_text(f"ok {nonce}\n")
                return
            time.sleep(0.02)
        raise AssertionError("backup was not requested")

    responder = None
    if mode != "stop-failure":
        responder = threading.Thread(target=answer_backup)
        responder.start()
    result = subprocess.run([updater, "--provider-reseed"], env=env,
                            capture_output=True, text=True, timeout=15)
    if responder:
        responder.join(timeout=10)
    calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
    assert (root / "stopped").exists()
    assert credential.read_text() == "synthetic login state"
    assert "provider reseed failed" in result.stderr if mode != "success" else result.returncode == 0
    if mode == "success":
        assert "previous provider prefix retained at" in result.stdout
        assert "provider prefix reseeded; agent ready" in result.stdout
        assert json.loads((fixture.package_dir(prefix, "@openai/codex") / "package.json").read_text())["version"] == "1.0.0"
        backups = list(prefix.parent.glob("npm.before-reseed-*"))
        assert len(backups) == 1
        assert json.loads((fixture.package_dir(backups[0], "@openai/codex") / "package.json").read_text())["version"] == "9.9.9"
        assert any(call[0] == "run" for call in calls)
        assert (root / "ready").exists()
    elif mode == "reseed-failure":
        assert result.returncode == 1
        assert (root / "disposable-cleanup").exists()
        assert "previous agent is not ready" in result.stderr
        assert json.loads((fixture.package_dir(prefix, "@openai/codex") / "package.json").read_text())["version"] == "9.9.9"
        assert not list(prefix.parent.glob("npm.before-reseed-*"))
        assert any(call[0] == "compose" and "up" in call for call in calls)
    else:
        assert result.returncode == 1
        assert "stop failed after partial quiescence" in result.stderr
        assert "previous agent ready after failed provider reseed" in result.stdout
        assert not (root / "request").exists()
        assert not any(call[0] == "run" for call in calls)


def main():
    with tempfile.TemporaryDirectory(prefix="provider-reseed-flow-", dir=Path.home() / ".cache") as scratch:
        for mode in ("success", "reseed-failure", "stop-failure"):
            exercise(Path(scratch) / mode, mode)
            print(f"{mode}: repair boundary verified")


if __name__ == "__main__":
    main()
