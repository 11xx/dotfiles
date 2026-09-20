#!/usr/bin/env bash
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
fixture=$(mktemp -d "$TMPDIR/gak-compose-lifecycle.XXXXXXXX")
cleanup_fixture() {
    if [[ -f "$fixture/detached.pid" ]]; then
        kill "$(cat "$fixture/detached.pid")" 2>/dev/null || true
    fi
    rm -rf -- "$fixture"
}
trap cleanup_fixture EXIT

helper=$(cd "$(dirname "$0")/../files" && pwd)/gak-compose-lifecycle
services_root="$fixture/services"
log_file="$fixture/podman.log"
event_file="$fixture/events.log"
network_root="$fixture/networks"
running_root="$fixture/running"
runtime_root="$fixture/runtime"
mkdir -p "$services_root" "$network_root" "$running_root" "$runtime_root"

fail() {
    printf 'lifecycle fixture: %s\n' "$*" >&2
    exit 1
}

assert_file() {
    if [[ ! -e $1 ]]; then
        find "$fixture" -maxdepth 3 -print >&2
        cat "$log_file" >&2 || true
        fail "missing expected file: $1"
    fi
}

assert_not_file() {
    [[ ! -e $1 ]] || fail "unexpected file: $1"
}

assert_log_contains() {
    grep -F -- "$1" "$log_file" >/dev/null || fail "log lacks: $1"
}

reset_fixture() {
    rm -rf -- "$services_root" "$log_file" "$event_file" "$network_root" "$running_root" "$runtime_root"
    mkdir -p "$services_root" "$network_root" "$running_root" "$runtime_root"
    : >"$log_file"
    : >"$event_file"
    unset FAKE_FAIL_UP FAKE_STOP_DELAY
}

declare_apps() {
    printf '%s\n' "$@" >"$services_root/.compose-applications"
    : >"$services_root/.compose-autostart"
    local application
    for application in "$@"; do
        mkdir -p "$services_root/$application"
        : >"$services_root/$application/compose.yaml"
    done
}

enable_apps() {
    printf '%s\n' "$@" >"$services_root/.compose-autostart"
}

write_fake_podman() {
    cat >"$fixture/fake-podman" <<'EOF'
#!/usr/bin/env bash
set -u

printf '%s|%s\n' "$PWD" "$*" >>"$FAKE_PODMAN_LOG"

if [[ ${1:-} == network ]]; then
    if [[ ${FAKE_DETACH:-0} == 1 && ! -f $FAKE_DETACHED_PID_FILE ]]; then
        sleep 60 >/dev/null 2>&1 &
        printf '%s\n' "$!" >"$FAKE_DETACHED_PID_FILE"
    fi
    case ${2:-} in
        exists)
            [[ -e "$FAKE_NETWORK_ROOT/${3:?}" ]]
            exit $?
            ;;
        create)
            mkdir -p "$FAKE_NETWORK_ROOT/${@: -1}"
            ;;
    esac
    exit 0
fi

if [[ ${1:-} == container && ${2:-} == exists ]]; then
    [[ -e "$FAKE_RUNNING_ROOT/${3:?}" ]]
    exit $?
fi

if [[ ${1:-} == compose ]]; then
    application=${PWD##*/}
    case " $* " in
        *' up '*)
            if [[ $application == nextcloud ]]; then
                : >"$FAKE_RUNNING_ROOT/nextcloud-cron"
                : >"$FAKE_RUNNING_ROOT/nextcloud"
                : >"$FAKE_RUNNING_ROOT/nextcloud-redis"
                : >"$FAKE_RUNNING_ROOT/nextcloud-db"
            else
                : >"$FAKE_RUNNING_ROOT/$application"
            fi
            if [[ ${FAKE_FAIL_UP:-} == "$application" ]]; then
                exit 23
            fi
            ;;
        *' stop '*)
            service=${@: -1}
            printf 'stop|%s|%s\n' "$application" "$service" >>"$FAKE_EVENT_LOG"
            sleep "${FAKE_STOP_DELAY:-0}"
            if [[ $application == nextcloud && $service != 30 ]]; then
                rm -f -- "$FAKE_RUNNING_ROOT/$service"
            else
                rm -f -- "$FAKE_RUNNING_ROOT/$application"
            fi
            ;;
    esac
fi
EOF
    chmod 0755 "$fixture/fake-podman"
}

run_service() {
    rm -f -- "$runtime_root/ready"
    "$helper" run >"$fixture/stdout" 2>"$fixture/stderr" &
    service_pid=$!
    for _ in {1..200}; do
        [[ -f "$runtime_root/ready" ]] && return 0
        if ! kill -0 "$service_pid" 2>/dev/null; then
            wait "$service_pid" || true
            cat "$fixture/stderr" >&2
            return 1
        fi
        sleep 0.01
    done
    return 1
}

stop_service() {
    kill -TERM "$service_pid"
    wait "$service_pid"
    flock -n "$runtime_root/lock" true || fail 'lifecycle lock remained held after stop'
}

export GAK_COMPOSE_SERVICES_ROOT="$services_root"
export GAK_COMPOSE_RUNTIME_DIR="$runtime_root"
export GAK_COMPOSE_DECLARED_FILE="$services_root/.compose-applications"
export GAK_COMPOSE_AUTOSTART_FILE="$services_root/.compose-autostart"
export GAK_COMPOSE_PODMAN="$fixture/fake-podman"
export FAKE_PODMAN_LOG="$log_file"
export FAKE_EVENT_LOG="$event_file"
export FAKE_NETWORK_ROOT="$network_root"
export FAKE_RUNNING_ROOT="$running_root"
export FAKE_DETACHED_PID_FILE="$fixture/detached.pid"
write_fake_podman

reset_fixture
declare_apps sabnzbd
enable_apps prowlarr
if "$helper" run >/dev/null 2>&1; then
    fail 'undeclared autostart entry was accepted'
fi
[[ ! -s $log_file ]] || fail 'validation invoked Podman'

reset_fixture
declare_apps sabnzbd
if ! run_service; then
    fail 'empty autostart list did not start the lifecycle process'
fi
[[ ! -s $log_file ]] || fail 'empty autostart list invoked Podman'
stop_service
assert_not_file "$runtime_root/started"
run_service || fail 'lifecycle did not restart in the same runtime directory'
stop_service

reset_fixture
declare_apps sabnzbd prowlarr
enable_apps sabnzbd prowlarr
run_service || fail 'selected stacks did not start'
assert_log_contains '|compose -f compose.yaml up -d --pull never'
! grep -E '\|.* (pull|down)( |$)' "$log_file" >/dev/null || fail 'startup pulled or tore down a project'
assert_file "$network_root/starrs_net"
assert_file "$network_root/services_net"
assert_file "$network_root/nextcloud_net"
: >"$running_root/unselected"
stop_service
[[ -e $running_root/unselected ]] || fail 'stop touched an unselected stack'
first_stop=$(grep 'stop|' "$event_file" | sed -n '1p')
second_stop=$(grep 'stop|' "$event_file" | sed -n '2p')
[[ $first_stop == 'stop|prowlarr|30' ]] || fail "wrong first stop: $first_stop"
[[ $second_stop == 'stop|sabnzbd|30' ]] || fail "wrong second stop: $second_stop"

reset_fixture
declare_apps sabnzbd prowlarr
enable_apps sabnzbd prowlarr
export FAKE_FAIL_UP=prowlarr
if "$helper" run >/dev/null 2>&1; then
    fail 'startup failure was hidden'
fi
assert_log_contains 'compose -f compose.yaml stop --timeout 30'
assert_not_file "$runtime_root/started"
unset FAKE_FAIL_UP

reset_fixture
declare_apps sonarr
enable_apps sonarr
printf '%s\n' sonarr >"$runtime_root/started"
run_service || fail 'stale ownership state blocked recovery'
stop_service
assert_not_file "$runtime_root/started"

reset_fixture
declare_apps sabnzbd
enable_apps sabnzbd
run_service || fail 'crash-recovery setup did not start'
kill -KILL "$service_pid"
wait "$service_pid" 2>/dev/null || true
assert_file "$runtime_root/started"
run_service || fail 'crash-recovery restart did not reconcile stale state'
grep -F 'stop|sabnzbd|30' "$event_file" >/dev/null || {
    cat "$event_file" >&2 || true
    cat "$log_file" >&2 || true
    fail 'crash recovery did not stop stale ownership'
}
stop_service

reset_fixture
declare_apps sabnzbd nextcloud
enable_apps sabnzbd nextcloud
export FAKE_FAIL_UP=nextcloud
if "$helper" run >/dev/null 2>&1; then
    fail 'partial project startup failure was hidden'
fi
grep -F 'stop|nextcloud|nextcloud' "$event_file" >/dev/null || {
    cat "$event_file" >&2 || true
    cat "$log_file" >&2 || true
    fail 'failed project was not retained for cleanup'
}
assert_not_file "$running_root/nextcloud"
assert_not_file "$runtime_root/started"
unset FAKE_FAIL_UP

reset_fixture
declare_apps nextcloud
enable_apps nextcloud
export FAKE_STOP_DELAY=0.1
run_service || fail 'nextcloud did not start'
started_at=$(date +%s%N)
stop_service
elapsed=$(( $(date +%s%N) - started_at ))
((elapsed >= 350000000)) || fail "stop returned before sequential waits: ${elapsed}ns"
mapfile -t stop_events < <(cut -d'|' -f3 "$event_file")
[[ ${stop_events[*]} == 'nextcloud-cron nextcloud nextcloud-redis nextcloud-db' ]] ||
    fail "wrong Nextcloud stop order: ${stop_events[*]}"

reset_fixture
declare_apps sabnzbd
enable_apps sabnzbd
export FAKE_DETACH=1
run_service || fail 'detached-backend setup failed'
stop_service
kill -0 "$(cat "$fixture/detached.pid")" || fail 'detached backend did not survive for the lock probe'
run_service || fail 'detached backend retained the lifecycle lock'
stop_service
unset FAKE_DETACH

if grep -F 'sudo' "$helper" >/dev/null; then
    fail 'helper contains a hidden sudo path'
fi
printf '%s\n' 'lifecycle fixture: passed'
