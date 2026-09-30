#!/usr/bin/env python3
"""Check that the agent and ingress roles render the same host port."""

from pathlib import Path
import os
import subprocess
import tempfile

import yaml


SYSTEM = Path(__file__).resolve().parents[2]
COLLECTION = Path(os.environ.get(
    "AIAGENT_REMOTE_COLLECTION_ROOT",
    SYSTEM / ".ansible/collections/ansible_collections/aiagent/remote",
)).resolve()
COMPOSE = COLLECTION / "roles/agent/templates/agent-compose.yaml.j2"
INGRESS = SYSTEM / "roles/gak_ingress/templates/tailscale-services.j2"
SHARED = SYSTEM / "group_vars/all/gak_agent"
INGRESS_DEFAULTS = SYSTEM / "roles/gak_ingress/defaults/main.yaml"


def main():
    default_port = yaml.safe_load(SHARED.read_text())["gak_t3_port"]
    existing = None
    with tempfile.TemporaryDirectory(prefix="t3-port-render-", dir=Path.home() / ".cache") as scratch:
        root = Path(scratch)
        config = root / "ansible.cfg"
        config.write_text(
            "[defaults]\n"
            f"collections_path = {COLLECTION.parents[2]}\n"
            f"local_tmp = {root / 'ansible-tmp'}\n"
            "retry_files_enabled = False\n"
            "interpreter_python = auto_silent\n"
        )
        (root / "ansible-tmp").mkdir()
        environment = dict(os.environ, ANSIBLE_CONFIG=str(config),
                           ANSIBLE_COLLECTIONS_PATH=str(COLLECTION.parents[2]))
        playbook = root / "render.yaml"
        playbook.write_text(yaml.safe_dump([{
            "hosts": "localhost",
            "gather_facts": False,
            "vars_files": [str(SHARED), str(INGRESS_DEFAULTS)],
            "vars": {
                "gak_aiagent_host_enabled": True,
                "aiagent_remote_agent_home": "/home/aiagent",
                "aiagent_remote_agent_t3_port": "{{ gak_t3_port }}",
                "gak_applications": ["koito", "nextcloud"],
                "gak_koito_service_name": "koito",
                "gak_koito_port": 4110,
                "gak_nextcloud_service_name": "nextcloud",
                "gak_nextcloud_port": 8080,
            },
            "tasks": [
                {"ansible.builtin.template": {"src": str(COMPOSE), "dest": str(root / "compose.yaml")}},
                {"ansible.builtin.template": {"src": str(INGRESS), "dest": str(root / "ingress.sh")}},
            ],
        }]))
        for port in (default_port, 4773):
            command = ["ansible-playbook", "-i", "localhost,", "-c", "local", str(playbook)]
            if port != default_port:
                command += ["-e", f"gak_t3_port={port}"]
            result = subprocess.run(command, capture_output=True, text=True,
                                    env=environment)
            assert result.returncode == 0, result.stdout + result.stderr
            compose = yaml.safe_load((root / "compose.yaml").read_text())
            assert compose["services"]["agent"]["ports"] == [f"127.0.0.1:{port}:3773"]
            ingress = (root / "ingress.sh").read_text()
            assert f"http://127.0.0.1:{port}" in ingress
            assert ingress.count("--service=svc:") == 3
            old_services = tuple(line for line in ingress.splitlines()
                                 if "--service=svc:koito" in line
                                 or "--service=svc:nextcloud" in line)
            if existing is None:
                existing = old_services
            else:
                assert old_services == existing
            print(f"host port {port}: Compose and Tailscale ingress agree")


if __name__ == "__main__":
    main()
