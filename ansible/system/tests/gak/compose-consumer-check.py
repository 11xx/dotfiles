#!/usr/bin/env python3
"""Check the consumer Compose mapping through its installed collection."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


SYSTEM = Path(__file__).resolve().parents[2]
COLLECTION = Path(os.environ.get(
    "AI_AGENT_REMOTE_COLLECTION_ROOT",
    SYSTEM / ".ansible/collections/ansible_collections/ai_agent/remote",
)).resolve()
if not (COLLECTION / "MANIFEST.json").is_file():
    raise SystemExit(f"installed collection is missing: {COLLECTION}")
COLLECTIONS_PATH = COLLECTION.parents[2]
CACHE = Path.home() / ".cache"
CACHE.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(
    prefix="ai-agent-remote-consumer-check.",
    dir=CACHE,
) as temporary:
    root = Path(temporary)
    config = root / "ansible.cfg"
    inventory = root / "hosts.yml"
    config.write_text(
        "[defaults]\n"
        f"roles_path={SYSTEM / 'roles'}\n"
        f"collections_path={COLLECTIONS_PATH}\n"
        "retry_files_enabled=False\n"
        "host_key_checking=False\n"
        "interpreter_python=auto_silent\n"
    )
    fixture_vars = {
        "ansible_connection": "local",
        "ansible_python_interpreter": sys.executable,
        "gak_applications": [],
        "gak_compose_autostart": [],
        "gak_compose_supported": [],
        "gak_compose_never_autostart": [],
        "gak_compose_external_networks": [],
        "gak_services_bin_dir": str(root / "bin"),
        "guix_home_config_dir": str(root / "guix"),
        "gak_aiagent_host_enabled": False,
        "gak_git_hub_enabled": False,
        "gak_activate_system": False,
    }
    inventory.write_text(json.dumps({
        "all": {"children": {"gak": {"hosts": {"consumer-fixture": fixture_vars}}}}
    }))
    environment = dict(
        os.environ,
        ANSIBLE_CONFIG=str(config),
        ANSIBLE_COLLECTIONS_PATH=str(COLLECTIONS_PATH),
    )
    result = subprocess.run([
        "ansible-playbook",
        "-i", str(inventory),
        str(SYSTEM / "gak.yaml"),
        "--limit", "gak",
        "--tags", "gak-compose",
        "--check",
    ], env=environment, capture_output=True, text=True)
    if result.returncode:
        raise SystemExit(result.stdout + result.stderr)

print("consumer Compose role: installed collection check passed without an injected services root")
