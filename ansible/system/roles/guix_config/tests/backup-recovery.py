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
        if arguments[0] == "findmnt":
            events.append("findmnt")
            return subprocess.CompletedProcess(arguments, 0)
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

    original = backup.run_process
    backup.run_process = fake_run
    try:
        try:
            backup.quiesced(lambda: events.append("snapshot"))
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            pass
        else:
            raise AssertionError("failed stop was accepted")
    finally:
        backup.run_process = original
    assert events == ["stop", "findmnt", "start", "enable", "start"], events


def remount():
    events = []
    mounted = False

    def fake_run(arguments, **_kwargs):
        nonlocal mounted
        if arguments[0] == "findmnt":
            events.append("findmnt")
            return subprocess.CompletedProcess(arguments, 0 if mounted else 1)
        action, service = arguments[1:]
        events.append(f"{action}:{service}")
        if action == "start" and service == "aiagent-home":
            mounted = True
        return subprocess.CompletedProcess(arguments, 0)

    original = backup.run_process
    backup.run_process = fake_run
    try:
        backup.recover_service()
    finally:
        backup.run_process = original
    assert events == ["findmnt", "start:aiagent-home", "findmnt", "start:aiagent-compose"], events


def stopped_home_record():
    events = []
    compose_starts = 0

    def fake_run(arguments, **_kwargs):
        nonlocal compose_starts
        if arguments[0] == "findmnt":
            events.append("findmnt")
            return subprocess.CompletedProcess(arguments, 0)
        action, service = arguments[1:]
        events.append(f"{action}:{service}")
        if action == "start" and service == "aiagent-compose":
            compose_starts += 1
            return subprocess.CompletedProcess(arguments, 0 if compose_starts == 3 else 1)
        return subprocess.CompletedProcess(arguments, 0)

    original = backup.run_process
    backup.run_process = fake_run
    try:
        backup.recover_service()
    finally:
        backup.run_process = original
    assert events == ["findmnt", "start:aiagent-compose", "enable:aiagent-compose",
                      "start:aiagent-compose", "start:aiagent-home", "findmnt",
                      "start:aiagent-compose"], events


def main():
    assert backup.STOP_TIMEOUT >= 2520
    for failure in ("timeout", "status"):
        exercise(failure)
    remount()
    stopped_home_record()
    print("failed and timed-out stops both attempted service recovery before exit")
    print("missing home was remounted before Compose restart")
    print("stopped home service record was restarted before Compose retry")


if __name__ == "__main__":
    main()
