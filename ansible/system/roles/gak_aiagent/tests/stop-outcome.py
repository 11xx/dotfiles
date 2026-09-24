#!/usr/bin/env python3
"""Probe exact-container shutdown status across the Podman caller boundary."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROLE = Path(__file__).resolve().parents[1]
SOURCE = ROLE / "files/aiagent-stop-outcome"
PODMAN = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

root = Path(os.environ["STOP_OUTCOME_TEST_ROOT"])
mode = os.environ["STOP_OUTCOME_TEST_MODE"]
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps(args) + "\\n")
stopped = (root / "stopped").exists()
old = "a" * 64
new = "b" * 64
if args[:2] == ["container", "exists"]:
    if mode == "existence-error":
        sys.exit(125)
    if mode == "absent" or (mode == "appeared" and not stopped):
        sys.exit(1)
    if mode == "name-disappeared" and stopped:
        sys.exit(1)
elif args[0] == "inspect":
    if mode == "inspect-error":
        sys.exit(125)
    reference = args[-1]
    if not stopped:
        if mode in ("historical", "paused", "inconsistent"):
            running = "true" if mode == "inconsistent" else "false"
            status = "paused" if mode == "paused" else "exited"
            print(f"{old}|{running}|{status}|124")
        else:
            print(f"{old}|true|running|0")
    elif mode == "replaced" and reference == "aiagent":
        print(f"{new}|true|running|0")
    elif mode == "appeared":
        print(f"{new}|true|running|0")
    elif mode == "still-running":
        print(f"{old}|true|running|0")
    elif mode == "historical":
        print(f"{old}|false|exited|124")
    else:
        code = 124 if mode in ("forced", "forced-compose-failure") else (7 if mode == "bad-exit" else 0)
        print(f"{old}|false|exited|{code}")
elif args[0] == "compose":
    (root / "stopped").touch()
    if mode in ("compose-failure", "forced-compose-failure"):
        sys.exit(38)
elif args[0] == "logs":
    print("private-log-sentinel")
    sys.exit(91)
'''


def replace_one(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new)


def exercise(root, mode, expected):
    root.mkdir()
    home = root / "home"
    home.mkdir()
    fake = root / "podman"
    fake.write_text(PODMAN)
    fake.chmod(0o755)
    source = SOURCE.read_text()
    source = replace_one(source, 'HOME = Path("/home/aiagent")', f"HOME = Path({str(home)!r})")
    source = replace_one(source, 'PODMAN = "/run/current-system/profile/bin/podman"',
                         f"PODMAN = {str(fake)!r}")
    helper = root / "aiagent-stop-outcome"
    helper.write_text(source)
    helper.chmod(0o755)
    env = dict(os.environ, STOP_OUTCOME_TEST_ROOT=str(root), STOP_OUTCOME_TEST_MODE=mode)
    result = subprocess.run([helper], env=env, capture_output=True, text=True, timeout=10)
    assert result.returncode == expected, (mode, result.stdout, result.stderr)
    assert "private-log-sentinel" not in result.stdout + result.stderr
    calls = [json.loads(line) for line in (root / "calls").read_text().splitlines()]
    assert not any(call[0] == "logs" for call in calls)
    if mode in ("forced", "replaced"):
        assert [call[0] for call in calls] == [
            "container", "inspect", "compose", "inspect", "container", "inspect"
        ]
        assert calls[1][-1] == "aiagent"
        assert calls[3][-1] == "a" * 64
        assert calls[5][-1] == "aiagent"
    if mode in ("paused", "inconsistent", "existence-error", "inspect-error"):
        assert not any(call[0] == "compose" for call in calls)
    if mode == "graceful":
        assert "stopped gracefully" in result.stdout
    if mode == "forced":
        assert "shutdown escalated" in result.stderr and "exit 124" in result.stderr
    if mode == "forced-compose-failure":
        assert "shutdown escalated" in result.stderr
        assert "Compose stop also exited 38" in result.stderr
    if mode == "historical":
        assert "historical exit 124" in result.stderr
        assert "shutdown escalated" not in result.stderr
    if mode == "absent":
        assert "no container was running" in result.stdout
    if mode in ("replaced", "appeared", "name-disappeared"):
        assert "stop failed" in result.stderr
    if mode == "compose-failure":
        assert "Compose stop exited 38" in result.stderr
        assert "stopped gracefully" not in result.stdout
    print(f"{mode}: exact-container stop result {expected}")


def main():
    with tempfile.TemporaryDirectory(prefix="aiagent-stop-outcome-", dir=Path.home() / ".cache") as scratch:
        for mode, expected in (
            ("graceful", 0), ("forced", 124), ("forced-compose-failure", 1),
            ("bad-exit", 1), ("compose-failure", 1), ("historical", 0),
            ("absent", 0), ("replaced", 1), ("appeared", 1),
            ("name-disappeared", 1), ("still-running", 1),
            ("paused", 1), ("inconsistent", 1), ("existence-error", 1),
            ("inspect-error", 1),
        ):
            exercise(Path(scratch) / mode, mode, expected)


if __name__ == "__main__":
    main()
