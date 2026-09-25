#!/usr/bin/env python3
"""Render the pinned collection's Compose policy for the media consumer."""

import os
from pathlib import Path
import subprocess
import tempfile

import yaml


SYSTEM = Path(__file__).resolve().parents[2]
COLLECTION = Path(os.environ.get(
    "AI_AGENT_REMOTE_COLLECTION_ROOT",
    SYSTEM / ".ansible/collections/ansible_collections/ai_agent/remote",
)).resolve()
COLLECTIONS_PATH = COLLECTION.parents[2]
ROLE = COLLECTION / "roles/compose_runtime"
media = yaml.safe_load((SYSTEM / "host_vars/gak/main").read_text())
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

gak_play = next(play for play in yaml.safe_load((SYSTEM / "gak.yaml").read_text())
                if play.get("hosts") == "gak" and "roles" in play)
compose_role = next(role for role in gak_play["roles"]
                    if role.get("role") == "ai_agent.remote.compose_runtime")
assert compose_role["vars"] == {
    "ai_agent_remote_compose_home": "{{ ansible_facts['user_dir'] }}",
    "ai_agent_remote_compose_services_root": "{{ ansible_facts['user_dir'] }}/services",
    "ai_agent_remote_compose_operator_bin_dir": "{{ gak_services_bin_dir }}",
    "ai_agent_remote_compose_package_source_dir": "{{ guix_home_config_dir }}/packages",
    "ai_agent_remote_compose_application_names": "{{ gak_applications }}",
    "ai_agent_remote_compose_autostart_names": "{{ gak_compose_autostart }}",
    "ai_agent_remote_compose_supported_names": "{{ gak_compose_supported }}",
    "ai_agent_remote_compose_never_autostart_names": "{{ gak_compose_never_autostart }}",
    "ai_agent_remote_compose_external_network_names": "{{ gak_compose_external_networks }}",
}

nextcloud_tasks = yaml.safe_load((SYSTEM / "roles/gak_nextcloud/tasks/main.yaml").read_text())
stop_task = next(task for task in nextcloud_tasks if task.get("name") ==
                 "gak_nextcloud: Deploy the lifecycle stop order")
with tempfile.TemporaryDirectory(prefix="gak-compose-list-render-") as temporary:
    root = Path(temporary)
    config = root / "ansible.cfg"
    config.write_text(
        "[defaults]\nretry_files_enabled=False\ninterpreter_python=auto_silent\n"
        f"collections_path={COLLECTIONS_PATH}\n"
    )
    environment = dict(os.environ, ANSIBLE_CONFIG=str(config),
                       ANSIBLE_COLLECTIONS_PATH=str(COLLECTIONS_PATH))
    cases = [
        ([], [], {"supported": ["sonarr"], "never_autostart": [], "networks": []}),
        (["sonarr", "jellyfin"], [],
         {"supported": ["sonarr", "jellyfin"], "never_autostart": [], "networks": []}),
        (media["gak_applications"], media["gak_compose_autostart"], baseline),
    ]
    for declared, enabled, instance in cases:
        services = root / "services"
        nextcloud_dir = services / "nextcloud"
        nextcloud_dir.mkdir(parents=True, exist_ok=True)
        playbook = root / "render.yaml"
        task = stop_task.copy()
        task["ansible.builtin.copy"] = dict(task["ansible.builtin.copy"])
        task["ansible.builtin.copy"]["src"] = str(
            SYSTEM / "roles/gak_nextcloud/files/compose-stop-order")
        task["ansible.builtin.copy"]["dest"] = str(nextcloud_dir / ".compose-stop-order")
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost",
            "connection": "local",
            "gather_facts": False,
            "vars": {
                "ai_agent_remote_compose_home": str(root),
                "ai_agent_remote_compose_services_root": str(services),
                "ai_agent_remote_compose_operator_bin_dir": str(root / "bin"),
                "ai_agent_remote_compose_package_source_dir": str(root / "packages"),
                "ai_agent_remote_compose_application_names": declared,
                "ai_agent_remote_compose_autostart_names": enabled,
                "ai_agent_remote_compose_supported_names": instance["supported"],
                "ai_agent_remote_compose_never_autostart_names": instance["never_autostart"],
                "ai_agent_remote_compose_external_network_names": instance["networks"],
                "ai_agent_remote_compose_directory_mode": "0755",
                "ai_agent_remote_compose_data_mode": "0644",
                "ai_agent_remote_compose_package_mode": "0644",
                "ai_agent_remote_compose_lifecycle_mode": "0755",
            },
            "roles": [{"role": "ai_agent.remote.compose_runtime"}],
            "tasks": [task],
        }], sort_keys=False))
        result = subprocess.run(
            ["ansible-playbook", "-i", "localhost,", str(playbook)],
            env=environment, capture_output=True, text=True,
        )
        if result.returncode:
            if "Local RPC server did not start" in result.stdout + result.stderr:
                raise SystemExit(77)
            raise RuntimeError(result.stdout + result.stderr)
        for name, values in [
            (".compose-applications", declared),
            (".compose-autostart", enabled),
            (".compose-supported", instance["supported"]),
            (".compose-never-autostart", instance["never_autostart"]),
            (".compose-networks", instance["networks"]),
        ]:
            expected = "".join(value + "\n" for value in values).encode()
            assert (services / name).read_bytes() == expected, name
        assert (nextcloud_dir / ".compose-stop-order").read_text().splitlines() == baseline["stop_order"]
print("installed Compose role: media lists and Nextcloud stop order match baseline")
