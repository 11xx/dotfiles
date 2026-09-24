#!/usr/bin/env python3
"""Exercise service recovery after a timed-out or failed stop."""

import importlib.util
from pathlib import Path
import subprocess


SOURCE = Path(__file__).resolve().parents[1] / "files/modules/aiagent/backup.py"
spec = importlib.util.spec_from_file_location("agent_backup", SOURCE)
backup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backup)


def exercise(stop_failure):
    events = []
    starts = 0

    def fake_run(arguments, **_kwargs):
        nonlocal starts
        action = arguments[1]
        events.append(action)
        if action == "stop":
            if stop_failure == "timeout":
                raise subprocess.TimeoutExpired(arguments, backup.STOP_TIMEOUT)
            raise subprocess.CalledProcessError(1, arguments)
        if action == "start":
            starts += 1
            return subprocess.CompletedProcess(arguments, 1 if starts == 1 else 0)
        assert action == "enable"
        return subprocess.CompletedProcess(arguments, 0)

    original = backup.subprocess.run
    backup.subprocess.run = fake_run
    try:
        try:
            backup.quiesced(lambda: events.append("snapshot"))
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            pass
        else:
            raise AssertionError("failed stop was accepted")
    finally:
        backup.subprocess.run = original
    assert events == ["stop", "start", "enable", "start"], events


def main():
    assert backup.STOP_TIMEOUT >= 2520
    for failure in ("timeout", "status"):
        exercise(failure)
    print("failed and timed-out stops both attempted service recovery before exit")


if __name__ == "__main__":
    main()
