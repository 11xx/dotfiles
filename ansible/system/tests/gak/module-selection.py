#!/usr/bin/env python3
"""Render every independent Guix concern selection with synthetic inputs."""

import os
from pathlib import Path
import subprocess
import tempfile

import yaml


SYSTEM = Path(__file__).resolve().parents[2]
TEMPLATE = SYSTEM / "roles/guix_config/templates/system.scm.j2"
BASE_VARS = {
    "gak_media_uid": 1000,
    "ak_address": "192.0.2.10",
    "ak_fqdn": "builder.example.invalid",
    "gak_address": "192.0.2.20",
    "gak_fqdn": "gak.example.invalid",
    "pak_address": "192.0.2.30",
    "pak_fqdn": "pak.example.invalid",
    "gak_subid_start": 100000,
    "gak_subid_count": 65536,
    "gak_services_bin_dir": "/home/operator/.local/bin",
    "ak_signing_key_sexp": "(public-key (ecc (curve Ed25519) (q #" + "0" * 64 + "#)))",
    "ssh_port": 22,
    "gak_applications": [],
    "gak_git_hub_admin_public_key": "ssh-ed25519 TEST-ONLY operator",
    "gak_git_hub_max_push_bytes": 33554432,
    "gak_aiagent_deploy_public_key": "ssh-ed25519 TEST-ONLY deploy",
    "gak_aiagent_shell_public_key": "ssh-ed25519 TEST-ONLY shell",
    "ansible_facts": {"user_dir": "/home/operator"},
}


def main():
    with tempfile.TemporaryDirectory(prefix="guix-module-selection-") as temporary:
        root = Path(temporary)
        config = root / "ansible.cfg"
        config.write_text(
            "[defaults]\nretry_files_enabled=False\ninterpreter_python=auto_silent\n"
            f"local_tmp={root / 'ansible-tmp'}\n"
        )
        (root / "ansible-tmp").mkdir()
        env = dict(os.environ, ANSIBLE_CONFIG=str(config))
        cases = [(True, True), (True, False), (False, True), (False, False)]
        for agent, gitolite in cases:
            output = root / f"system-{int(agent)}-{int(gitolite)}.scm"
            playbook = root / "render.yaml"
            playbook.write_text(yaml.safe_dump([{
                "hosts": "localhost",
                "connection": "local",
                "gather_facts": False,
                "vars": {
                    **BASE_VARS,
                    "gak_aiagent_host_enabled": agent,
                    "gak_git_hub_enabled": gitolite,
                },
                "tasks": [{"ansible.builtin.template": {
                    "src": str(TEMPLATE), "dest": str(output),
                }}],
            }]))
            result = subprocess.run(
                ["ansible-playbook", "-i", "localhost,", str(playbook)],
                env=env, capture_output=True, text=True,
            )
            if result.returncode:
                if "Local RPC server did not start" in result.stdout + result.stderr:
                    raise SystemExit(77)
                raise RuntimeError(result.stdout + result.stderr)
            rendered = output.read_text()
            assert ("(aiagent host)" in rendered) == agent
            assert ("(service aiagent-host-service-type" in rendered) == agent
            assert ("(aiagent git-hub)" in rendered) == gitolite
            assert ("(git-hub-services %git-hub-config)" in rendered) == gitolite
            print(f"agent={agent}, gitolite={gitolite}: independent imports and services match")


if __name__ == "__main__":
    main()
