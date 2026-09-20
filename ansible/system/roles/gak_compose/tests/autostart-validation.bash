#!/usr/bin/env bash
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
fixture=$(mktemp -d "$TMPDIR/gak-compose-validation.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

mkdir -p "$fixture/ansible-tmp"
cat >"$fixture/ansible.cfg" <<EOF
[defaults]
retry_files_enabled = False
interpreter_python = auto_silent
local_tmp = $fixture/ansible-tmp
EOF
cat >"$fixture/inventory" <<'EOF'
[all]
localhost ansible_connection=local
EOF
cat >"$fixture/validate.yml" <<'EOF'
---
- name: Validate Compose selection
  hosts: all
  gather_facts: false
  tasks:
    - name: Validate the explicit application list
      ansible.builtin.assert:
        that:
          - gak_applications | type_debug == 'list'
          - gak_applications | unique | length == gak_applications | length

    - name: Validate the explicit Compose autostart list
      ansible.builtin.assert:
        that:
          - gak_compose_autostart | type_debug == 'list'
          - gak_compose_autostart | unique | length == gak_compose_autostart | length
          - gak_compose_autostart | difference(gak_applications) | length == 0
          - "'recyclarr' not in gak_compose_autostart"
EOF

declared='["sabnzbd","prowlarr","sonarr","radarr","jellyfin","qbittorrent","recyclarr","koito","nextcloud"]'
valid='["sabnzbd","prowlarr","sonarr","radarr","jellyfin","qbittorrent","koito","nextcloud"]'

run_case() {
    local name=$1
    local enabled=$2
    local expected=$3
    local extra
    extra=$(printf '{"gak_applications":%s,"gak_compose_autostart":%s}' "$declared" "$enabled")
    if ANSIBLE_CONFIG="$fixture/ansible.cfg" ansible-playbook \
        -i "$fixture/inventory" "$fixture/validate.yml" -e "$extra" \
        >"$fixture/$name.log" 2>&1; then
        actual=pass
    else
        actual=fail
    fi
    if grep -F 'Local RPC server did not start' "$fixture/$name.log" >/dev/null; then
        printf '%s\n' 'autostart validation fixture: skipped (Ansible local RPC unavailable)' >&2
        exit 77
    fi
    [[ $actual == "$expected" ]] || {
        cat "$fixture/$name.log" >&2
        printf 'validation case %s expected %s, got %s\n' "$name" "$expected" "$actual" >&2
        exit 1
    }
}

run_case default "$valid" pass
run_case empty '[]' pass
run_case duplicate '["sonarr","sonarr"]' fail
run_case undeclared '["missing"]' fail
run_case forbidden '["recyclarr"]' fail
printf '%s\n' 'autostart validation fixture: passed'
