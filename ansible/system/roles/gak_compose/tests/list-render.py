#!/usr/bin/env python3
"""Exercise the deployed list tasks, including native-template empty results."""
import os
from pathlib import Path
import subprocess
import tempfile

import yaml


source = Path(__file__).resolve().parents[1] / "tasks/main.yaml"
tasks = [
    task for task in yaml.safe_load(source.read_text())
    if "content" in task.get("ansible.builtin.copy", {})
]
assert len(tasks) == 2

with tempfile.TemporaryDirectory(prefix="gak-compose-list-render-") as temporary:
    root = Path(temporary)
    config = root / "ansible.cfg"
    config.write_text("[defaults]\nretry_files_enabled=False\ninterpreter_python=auto_silent\n")
    environment = os.environ.copy()
    environment["ANSIBLE_CONFIG"] = str(config)
    for declared, enabled in [([], []), (["sonarr", "jellyfin"], []),
                              (["sonarr", "jellyfin"], ["sonarr", "jellyfin"])]:
        playbook = root / "render.yaml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost", "connection": "local", "gather_facts": False,
            "vars": {
                "gak_applications": declared,
                "gak_compose_autostart": enabled,
                "gak_compose_declared_file": str(root / "declared"),
                "gak_compose_autostart_file": str(root / "enabled"),
            },
            "tasks": tasks,
        }], sort_keys=False))
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", str(playbook)],
            env=environment, capture_output=True, text=True,
        )
        if result.returncode:
            if "Local RPC server did not start" in result.stdout + result.stderr:
                raise SystemExit(77)
            raise RuntimeError(result.stdout + result.stderr)
        for name, values in [("declared", declared), ("enabled", enabled)]:
            expected = "".join(value + "\n" for value in values).encode()
            assert (root / name).read_bytes() == expected, name
print("actual list rendering: passed")
