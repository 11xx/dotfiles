#!/usr/bin/env bash
# Renders the deployed artifacts with Ansible and reads the result back through
# the real Compose provider, so the Nextcloud update gate is proven as deployed
# rather than as written. No container, image or backup is touched.
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
here=$(cd "$(dirname "$0")" && pwd)
system=$(cd "$here/../../.." && pwd)
updater="$here/../files/gak-services"

command -v ansible-playbook >/dev/null || {
    printf '%s\n' 'nextcloud extension fixture: skipped (no ansible-playbook)' >&2
    exit 77
}
command -v podman >/dev/null || {
    printf '%s\n' 'nextcloud extension fixture: skipped (no podman)' >&2
    exit 77
}

fixture=$(mktemp -d "$TMPDIR/gak-nextcloud-extension.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

# shellcheck source=fixture-profile.sh
. "$here/fixture-profile.sh"
make_fixture_profile "$fixture/profile" || {
    printf '%s\n' 'nextcloud extension fixture: skipped (no python3)' >&2
    exit 77
}
if ! "$fixture/profile/bin/python3" -I -c 'import yaml' 2>/dev/null; then
    printf '%s\n' 'nextcloud extension fixture: skipped (the fixture interpreter has no PyYAML)' >&2
    exit 77
fi
export GAK_SERVICES_HOME_PROFILE="$fixture/profile"

fail() {
    printf 'nextcloud extension fixture: %s\n' "$*" >&2
    exit 1
}

bin_dir="$fixture/bin"
services_root="$fixture/services"
project="$services_root/nextcloud"
mkdir -p "$bin_dir" "$project" "$fixture/ansible-tmp"

cat >"$fixture/ansible.cfg" <<EOF
[defaults]
retry_files_enabled = False
interpreter_python = auto_silent
local_tmp = $fixture/ansible-tmp
EOF

cat >"$fixture/render.yaml" <<EOF
---
- name: Render the deployed update artifacts
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    gak_services_bin_dir: $bin_dir
    gak_nextcloud_dir: $fixture/state/nextcloud
    gak_nextcloud_backup_dir: $fixture/backups/nextcloud
    gak_nextcloud_image: example.invalid/nextcloud:34-apache
    gak_nextcloud_postgres_image: example.invalid/postgres:17-alpine
    gak_nextcloud_redis_image: example.invalid/redis:8.2-alpine
    gak_nextcloud_port: 8080
    gak_nextcloud_admin_user: fixture-admin
    gak_nextcloud_hostname: nextcloud.fixture.invalid
  tasks:
    - name: Render the Nextcloud Compose project
      ansible.builtin.template:
        src: $system/roles/gak_nextcloud/templates/compose.yaml.j2
        dest: $project/compose.yaml
        mode: '0644'

    - name: Render the Nextcloud operator commands
      ansible.builtin.template:
        src: $system/roles/gak_nextcloud/templates/{{ item.src }}
        dest: $bin_dir/{{ item.dest }}
        mode: '0755'
      loop:
        - src: nextcloud-backup.j2
          dest: gak-nextcloud-backup
        - src: nextcloud-update-ready.j2
          dest: gak-nextcloud-update-ready

    - name: Deploy the update command
      ansible.builtin.copy:
        src: $system/roles/gak_compose/files/{{ item.src }}
        dest: $bin_dir/{{ item.dest }}
        mode: '{{ item.mode }}'
      loop:
        - src: gak-services
          dest: gak-services
          mode: '0755'
        - src: gak-services.py
          dest: gak-services.py
          mode: '0644'
EOF

if ! ANSIBLE_CONFIG="$fixture/ansible.cfg" ansible-playbook \
    -i localhost, "$fixture/render.yaml" >"$fixture/render.log" 2>&1; then
    if grep -F 'Local RPC server did not start' "$fixture/render.log" >/dev/null; then
        printf '%s\n' 'nextcloud extension fixture: skipped (Ansible local RPC unavailable)' >&2
        exit 77
    fi
    cat "$fixture/render.log" >&2
    fail 'rendering the deployed artifacts failed'
fi

[[ -x "$bin_dir/gak-services" ]] || fail 'the update command was not deployed executable'
cmp -s "$updater" "$bin_dir/gak-services" || fail 'the deployed update command differs from its source'
cmp -s "$here/../files/gak-services.py" "$bin_dir/gak-services.py" ||
    fail 'the deployed implementation differs from its source'
[[ -x "$bin_dir/gak-nextcloud-backup" ]] || fail 'the backup command was not deployed executable'
[[ -x "$bin_dir/gak-nextcloud-update-ready" ]] ||
    fail 'the readiness command was not deployed executable'
bash -n "$bin_dir/gak-nextcloud-update-ready" ||
    fail 'the rendered readiness command does not parse'
bash -n "$bin_dir/gak-nextcloud-backup" || fail 'the rendered backup command does not parse'
grep -F 'exit 75' "$bin_dir/gak-nextcloud-backup" >/dev/null ||
    fail 'the rendered backup command still treats lock contention as success'

export FAKE_STATE="$fixture/state/fake"
export FAKE_LOG="$fixture/podman.log"
export FAKE_DETACHED_PID="$fixture/detached.pid"
export FAKE_REAL_PODMAN=podman
export GAK_COMPOSE_PODMAN="$here/fake-podman"
export GAK_SERVICES_RUNTIME_DIR="$fixture/runtime"
export GAK_COMPOSE_SERVICES_ROOT="$services_root"
mkdir -p "$FAKE_STATE" "$fixture/runtime"
: >"$FAKE_STATE/containers.tsv"
: >"$FAKE_STATE/images.tsv"
: >"$FAKE_LOG"

if ! "$bin_dir/gak-services" list >"$fixture/stdout" 2>"$fixture/stderr"; then
    cat "$fixture/stderr" >&2
    fail 'the rendered Nextcloud project was rejected'
fi
grep -F 'nextcloud [stopped] services: nextcloud nextcloud-cron nextcloud-db nextcloud-redis' \
    "$fixture/stdout" >/dev/null || {
    cat "$fixture/stdout" >&2
    fail 'the rendered project did not declare its four services'
}
grep -F "before-update: $bin_dir/gak-nextcloud-backup" "$fixture/stdout" >/dev/null ||
    fail 'the rendered project did not declare its backup gate'
grep -F "readiness: $bin_dir/gak-nextcloud-update-ready" "$fixture/stdout" >/dev/null ||
    fail 'the rendered project did not declare its readiness command'
grep -F '(timeout 600s)' "$fixture/stdout" >/dev/null ||
    fail 'the rendered project did not carry its readiness bound'

# The gate has to be reachable as deployed, so removing it must be refused
# rather than silently skipped.
chmod 0644 "$bin_dir/gak-nextcloud-backup"
if "$bin_dir/gak-services" list >/dev/null 2>"$fixture/stderr"; then
    fail 'an unusable backup gate was accepted'
fi
grep -F 'not executable' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the unusable gate'

printf '%s\n' 'nextcloud extension fixture: passed'
