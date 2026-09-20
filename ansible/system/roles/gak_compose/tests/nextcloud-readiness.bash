#!/usr/bin/env bash
# Drives the rendered Nextcloud readiness command against a status endpoint
# serving canned documents, so the typed claims it checks are exercised rather
# than assumed. No container, image or backup is touched.
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
here=$(cd "$(dirname "$0")" && pwd)
system=$(cd "$here/../../.." && pwd)

for tool in ansible-playbook curl python3; do
    command -v "$tool" >/dev/null || {
        printf '%s\n' "nextcloud readiness fixture: skipped (no $tool)" >&2
        exit 77
    }
done

fixture=$(mktemp -d "$TMPDIR/gak-nextcloud-readiness.XXXXXXXX")
server_pid=
cleanup() {
    [[ -n $server_pid ]] && kill "$server_pid" 2>/dev/null
    rm -rf -- "$fixture"
}
trap cleanup EXIT

fail() {
    printf 'nextcloud readiness fixture: %s\n' "$*" >&2
    [[ -s "$fixture/stderr" ]] && cat "$fixture/stderr" >&2
    exit 1
}

bin_dir="$fixture/bin"
mkdir -p "$bin_dir" "$fixture/ansible-tmp"
source "$here/fixture-profile.sh"
make_fixture_profile "$fixture/profile"
export GAK_SERVICES_HOME_PROFILE="$fixture/profile"
cat >"$fixture/ansible.cfg" <<EOF
[defaults]
retry_files_enabled = False
interpreter_python = auto_silent
local_tmp = $fixture/ansible-tmp
EOF
cat >"$fixture/render.yaml" <<EOF
---
- hosts: localhost
  connection: local
  gather_facts: false
  vars:
    gak_nextcloud_port: 8080
  tasks:
    - ansible.builtin.template:
        src: $system/roles/gak_nextcloud/templates/nextcloud-update-ready.j2
        dest: $bin_dir/gak-nextcloud-update-ready
        mode: '0755'
EOF
if ! ANSIBLE_CONFIG="$fixture/ansible.cfg" ansible-playbook \
    -i localhost, "$fixture/render.yaml" >"$fixture/render.log" 2>&1; then
    if grep -F 'Local RPC server did not start' "$fixture/render.log" >/dev/null; then
        printf '%s\n' 'nextcloud readiness fixture: skipped (Ansible local RPC unavailable)' >&2
        exit 77
    fi
    cat "$fixture/render.log" >&2
    fail 'rendering the readiness command failed'
fi

probe="$bin_dir/gak-nextcloud-update-ready"
[[ -x $probe ]] || fail 'the readiness command was not deployed executable'
bash -n "$probe" || fail 'the rendered readiness command does not parse'

# A status endpoint whose answer, status code and delay come from files, so one
# server covers every case.
cat >"$fixture/server.py" <<'PY'
import http.server
import pathlib
import sys
import time

root = pathlib.Path(sys.argv[1])


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(float((root / "delay").read_text().strip() or 0))
        code = int((root / "code").read_text().strip())
        body = (root / "body").read_bytes()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
(root / "port").write_text(str(server.server_address[1]))
server.serve_forever()
PY

printf '0\n' >"$fixture/delay"
printf '200\n' >"$fixture/code"
printf '{}\n' >"$fixture/body"
python3 "$fixture/server.py" "$fixture" &
server_pid=$!
for _ in {1..200}; do
    [[ -s "$fixture/port" ]] && break
    sleep 0.05
done
[[ -s "$fixture/port" ]] || fail 'the status endpoint did not start'
export GAK_NEXTCLOUD_STATUS_URL="http://127.0.0.1:$(cat "$fixture/port")/status.php"

serve() {
    printf '%s\n' "${2:-200}" >"$fixture/code"
    printf '%s\n' "${3:-0}" >"$fixture/delay"
    printf '%s' "$1" >"$fixture/body"
}

expect() {
    local wanted=$1 label=$2
    set +e
    "$probe" >"$fixture/stdout" 2>"$fixture/stderr"
    local actual=$?
    set -e
    if [[ $wanted == ready ]]; then
        ((actual == 0)) || { cat "$fixture/stderr" >&2; fail "expected ready: $label"; }
    else
        ((actual != 0)) || fail "expected a refusal: $label"
    fi
}

healthy='{"installed":true,"maintenance":false,"needsDbUpgrade":false,"version":"34.0.4.1","versionstring":"34.0.4","edition":"","productname":"Nextcloud","extendedSupport":false}'

serve "$healthy"
expect ready 'a healthy instance'

serve "${healthy/\"maintenance\":false/\"maintenance\":true}"
expect refusal 'maintenance mode'
grep -F '"maintenance":false' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the claim that failed'

serve "${healthy/\"installed\":true/\"installed\":false}"
expect refusal 'an instance that is not installed'

serve "${healthy/\"needsDbUpgrade\":false/\"needsDbUpgrade\":true}"
expect refusal 'a pending database upgrade'

# A string where a boolean belongs is not the boolean.
serve "${healthy/\"installed\":true/\"installed\":\"true\"}"
expect refusal 'a quoted boolean'

serve '<html><body>installed true maintenance false</body></html>'
expect refusal 'a document that is not JSON'

serve '{"installed":true,"maintenance":fal'
expect refusal 'a truncated document'

serve '{"installed":trueX,"maintenance":false,"needsDbUpgrade":false}'
expect refusal 'invalid JSON with healthy-looking prefixes'

serve '{"nested":{"installed":true,"maintenance":false,"needsDbUpgrade":false}}'
expect refusal 'claims outside the top-level status object'

serve '{"installed":1,"maintenance":0,"needsDbUpgrade":0}'
expect refusal 'numeric values instead of booleans'

serve "$healthy" 503
expect refusal 'an unhealthy HTTP status'

serve "$healthy" 200 3
GAK_NEXTCLOUD_STATUS_TIMEOUT=1
export GAK_NEXTCLOUD_STATUS_TIMEOUT
started_at=$(date +%s)
expect refusal 'a response slower than the transport bound'
elapsed=$(( $(date +%s) - started_at ))
((elapsed < 10)) || fail "the transport bound did not hold: ${elapsed}s"
unset GAK_NEXTCLOUD_STATUS_TIMEOUT

kill "$server_pid" 2>/dev/null
wait "$server_pid" 2>/dev/null || true
server_pid=
expect refusal 'an endpoint that refuses the connection'
grep -F 'did not answer' "$fixture/stderr" >/dev/null ||
    fail 'the transport refusal was not reported as such'

printf '%s\n' 'nextcloud readiness fixture: passed'
