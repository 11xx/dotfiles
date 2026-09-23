#!/usr/bin/env python3
"""Exercise the deployed instance list tasks with empty and media inputs."""
import os
from pathlib import Path
import subprocess
import tempfile

import yaml


source = Path(__file__).resolve().parents[1] / "tasks/main.yaml"
system = source.parents[3]
tasks = [
    task for task in yaml.safe_load(source.read_text())
    if "content" in task.get("ansible.builtin.copy", {})
]
assert len(tasks) == 3
media = yaml.safe_load((system / "host_vars/gak/main").read_text())
baseline = {
    "supported": ["sabnzbd", "prowlarr", "sonarr", "radarr", "jellyfin",
                  "qbittorrent", "recyclarr", "koito", "nextcloud"],
    "never_autostart": ["recyclarr"],
    "networks": ["starrs_net", "services_net", "nextcloud_net"],
    "stop_order": ["nextcloud-cron", "nextcloud", "nextcloud-redis", "nextcloud-db"],
}
assert media["gak_compose_supported"] == baseline["supported"]
assert media["gak_applications"] == baseline["supported"]
assert media["gak_compose_autostart"] == [
    project for project in baseline["supported"]
    if project not in baseline["never_autostart"]
]
assert media["gak_compose_never_autostart"] == baseline["never_autostart"]
assert media["gak_compose_external_networks"] == baseline["networks"]

nextcloud_tasks = yaml.safe_load((system / "roles/gak_nextcloud/tasks/main.yaml").read_text())
stop_task = next(task for task in nextcloud_tasks if task.get("name") ==
                 "gak_nextcloud: Deploy the lifecycle stop order")
stop_task["ansible.builtin.copy"]["src"] = str(
    system / "roles/gak_nextcloud/files/compose-stop-order")

with tempfile.TemporaryDirectory(prefix="gak-compose-list-render-") as temporary:
    root = Path(temporary)
    config = root / "ansible.cfg"
    config.write_text("[defaults]\nretry_files_enabled=False\ninterpreter_python=auto_silent\n")
    environment = os.environ.copy()
    environment["ANSIBLE_CONFIG"] = str(config)
    cases = [
        ([], [], {"supported": ["sonarr"], "never_autostart": [], "networks": []}),
        (["sonarr", "jellyfin"], [],
         {"supported": ["sonarr", "jellyfin"], "never_autostart": [], "networks": []}),
        (media["gak_applications"], media["gak_compose_autostart"], baseline),
    ]
    for declared, enabled, instance in cases:
        (root / "nextcloud").mkdir(exist_ok=True)
        playbook = root / "render.yaml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost", "connection": "local", "gather_facts": False,
            "vars": {
                "gak_applications": declared,
                "gak_compose_autostart": enabled,
                "gak_compose_supported": instance["supported"],
                "gak_compose_never_autostart": instance["never_autostart"],
                "gak_compose_external_networks": instance["networks"],
                "gak_compose_declared_file": str(root / "declared"),
                "gak_compose_autostart_file": str(root / "enabled"),
                "gak_compose_supported_file": str(root / "supported"),
                "gak_compose_never_autostart_file": str(root / "never_autostart"),
                "gak_compose_networks_file": str(root / "networks"),
                "gak_nextcloud_dir": str(root / "nextcloud"),
            },
            "tasks": tasks + [stop_task],
        }], sort_keys=False))
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", str(playbook)],
            env=environment, capture_output=True, text=True,
        )
        if result.returncode:
            if "Local RPC server did not start" in result.stdout + result.stderr:
                raise SystemExit(77)
            raise RuntimeError(result.stdout + result.stderr)
        for name, values in [("declared", declared), ("enabled", enabled),
                             ("supported", instance["supported"]),
                             ("never_autostart", instance["never_autostart"]),
                             ("networks", instance["networks"]),
                             ("nextcloud/.compose-stop-order", baseline["stop_order"])]:
            expected = "".join(value + "\n" for value in values).encode()
            assert (root / name).read_bytes() == expected, name
print("actual list rendering: passed (media lists and stop order match baseline)")
