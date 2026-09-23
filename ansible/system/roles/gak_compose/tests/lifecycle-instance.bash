#!/usr/bin/env bash
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
fixture=$(mktemp -d "$TMPDIR/gak-compose-instance.XXXXXXXX")
service_pid=
cleanup() {
    if [[ -n $service_pid ]]; then
        kill -TERM "$service_pid" 2>/dev/null || true
        wait "$service_pid" 2>/dev/null || true
    fi
    rm -rf -- "$fixture"
}
trap cleanup EXIT

helper=$(cd "$(dirname "$0")/../files" && pwd)/gak-compose-lifecycle
export HOME="$fixture/agent-home"
export GAK_COMPOSE_SERVICES_ROOT="$HOME/workloads"
export GAK_COMPOSE_RUNTIME_DIR="$HOME/run/lifecycle"
export GAK_COMPOSE_PODMAN="$fixture/podman"
export FAKE_STATE="$fixture/containers"
export FAKE_EVENTS="$fixture/events"
export FAKE_NETWORKS="$fixture/networks"
mkdir -p "$GAK_COMPOSE_SERVICES_ROOT" "$FAKE_NETWORKS" "$HOME/run"
: >"$FAKE_STATE"
: >"$FAKE_EVENTS"

fail() {
    printf 'lifecycle instance fixture: %s\n' "$*" >&2
    exit 1
}

cat >"$GAK_COMPOSE_PODMAN" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $1 == network ]]; then
    case $2 in
        exists) [[ -e $FAKE_NETWORKS/$3 ]] ;;
        create) : >"$FAKE_NETWORKS/${@: -1}" ;;
    esac
    exit $?
fi
if [[ $1 == ps ]]; then
    [[ ${2:-} == -a && ${@: -1} == '{{.Names}} {{.Label "com.docker.compose.service"}}' ]] || exit 90
    [[ ${FAKE_PS_FAIL:-0} != 1 ]] || exit 94
    project=
    workdir=
    for arg in "$@"; do
        case $arg in
            label=com.docker.compose.project=*) project=${arg#label=com.docker.compose.project=} ;;
            label=com.docker.compose.project.working_dir=*) workdir=${arg#label=com.docker.compose.project.working_dir=} ;;
        esac
    done
    [[ -n $workdir ]] || exit 90
    awk -F'|' -v p="$project" -v d="$workdir" \
        '$2 == d && (p == "" || $1 == p) {print $4, $3}' "$FAKE_STATE"
    exit 0
fi
[[ $1 == compose && $2 == -f && $3 == compose.yaml ]] || exit 91
project=${PWD##*/}
if [[ $4 == up ]]; then
    case $project in
        lab)
            printf 'named-lab|%s|alpha|unrelated-alpha\nnamed-lab|%s|beta|unrelated-beta\n' "$PWD" "$PWD" >>"$FAKE_STATE"
            ;;
        relay) printf 'relay|%s|relay|odd-container-name\n' "$PWD" >>"$FAKE_STATE" ;;
        *) exit 92 ;;
    esac
    printf 'up|%s\n' "$project" >>"$FAKE_EVENTS"
elif [[ $4 == stop ]]; then
    service=${7:-all}
    printf 'stop|%s|%s\n' "$project" "$service" >>"$FAKE_EVENTS"
    awk -F'|' -v d="$PWD" -v s="$service" \
        '!($2 == d && (s == "all" || $3 == s))' "$FAKE_STATE" >"$FAKE_STATE.next"
    mv "$FAKE_STATE.next" "$FAKE_STATE"
else
    exit 93
fi
EOF
chmod 0755 "$GAK_COMPOSE_PODMAN"

printf '%s\n' lab relay batch >"$GAK_COMPOSE_SERVICES_ROOT/.compose-supported"
printf '%s\n' lab relay batch >"$GAK_COMPOSE_SERVICES_ROOT/.compose-applications"
printf '%s\n' lab relay >"$GAK_COMPOSE_SERVICES_ROOT/.compose-autostart"
printf '%s\n' batch >"$GAK_COMPOSE_SERVICES_ROOT/.compose-never-autostart"
printf '%s\n' agent_net >"$GAK_COMPOSE_SERVICES_ROOT/.compose-networks"
for project in lab relay batch; do
    mkdir "$GAK_COMPOSE_SERVICES_ROOT/$project"
    : >"$GAK_COMPOSE_SERVICES_ROOT/$project/compose.yaml"
done
printf 'name: named-lab\nservices: {}\n' >"$GAK_COMPOSE_SERVICES_ROOT/lab/compose.yaml"
printf '%s\n' beta alpha >"$GAK_COMPOSE_SERVICES_ROOT/lab/.compose-stop-order"

start() {
    rm -f -- "$GAK_COMPOSE_RUNTIME_DIR/ready"
    "$helper" run >"$fixture/stdout" 2>"$fixture/stderr" &
    service_pid=$!
    for _ in {1..200}; do
        [[ ! -e $GAK_COMPOSE_RUNTIME_DIR/ready ]] || return 0
        if ! kill -0 "$service_pid" 2>/dev/null; then
            cat "$fixture/stderr" >&2
            fail 'helper exited before readiness'
        fi
        sleep 0.01
    done
    fail 'readiness timed out'
}

stop() {
    kill -TERM "$service_pid"
    wait "$service_pid" || fail 'helper stop failed'
    service_pid=
}

start
[[ -e $FAKE_NETWORKS/agent_net ]] || fail 'external network was not created'
[[ $(grep -c '^up|' "$FAKE_EVENTS") == 2 ]] || fail 'unexpected autostart selection'
printf 'named-lab|%s|impostor|lab\n' "$fixture/elsewhere" >>"$FAKE_STATE"
stop
mapfile -t stops < <(grep '^stop|' "$FAKE_EVENTS")
[[ ${stops[*]} == 'stop|relay|all stop|lab|beta stop|lab|alpha' ]] || fail "wrong stop order: ${stops[*]}"
grep -Fq "named-lab|$fixture/elsewhere|impostor|lab" "$FAKE_STATE" || fail 'foreign project container was stopped'
[[ $(wc -l <"$FAKE_STATE") == 1 ]] || fail 'project containers were not stopped'

: >"$FAKE_EVENTS"
start
kill -KILL "$service_pid"
wait "$service_pid" 2>/dev/null || true
service_pid=
[[ -e $GAK_COMPOSE_RUNTIME_DIR/started ]] || fail 'crash lost ownership state'
start
[[ $(grep -c '^stop|' "$FAKE_EVENTS") == 3 ]] || fail 'stale ownership was not reconciled'
stop

: >"$FAKE_EVENTS"
start
kill -KILL "$service_pid"
wait "$service_pid" 2>/dev/null || true
service_pid=
export FAKE_PS_FAIL=1
if "$helper" run >"$fixture/query.out" 2>"$fixture/query.err"; then
    fail 'failed container query was accepted during stale recovery'
fi
grep -Fq 'could not query project containers' "$fixture/query.err" || fail 'query failure was not reported'
[[ -e $GAK_COMPOSE_RUNTIME_DIR/started ]] || fail 'query failure lost ownership state'
unset FAKE_PS_FAIL
start
[[ $(grep -c '^stop|' "$FAKE_EVENTS") == 3 ]] || fail 'query retry did not reconcile ownership'
stop

printf 'lab\n' >"$GAK_COMPOSE_RUNTIME_DIR/started"
"$helper" stop >"$fixture/empty.out" 2>"$fixture/empty.err" || fail 'empty recorded project could not stop'
grep -Fq 'no containers for recorded application: lab' "$fixture/empty.err" || fail 'empty result was silent'
[[ ! -e $GAK_COMPOSE_RUNTIME_DIR/started ]] || fail 'empty result retained stale ownership'

reject() {
    if "$helper" run >"$fixture/reject.out" 2>"$fixture/reject.err"; then
        fail "malformed instance data was accepted: $1"
    fi
    grep -Fq "$1" "$fixture/reject.err" || fail "wrong refusal for $1"
}
mv "$GAK_COMPOSE_SERVICES_ROOT/.compose-networks" "$fixture/networks.saved"
reject 'required list is missing'
mv "$fixture/networks.saved" "$GAK_COMPOSE_SERVICES_ROOT/.compose-networks"
printf '%s\n' 'bad network' >"$GAK_COMPOSE_SERVICES_ROOT/.compose-networks"
reject 'invalid entry'
printf '%s\n' agent_net >"$GAK_COMPOSE_SERVICES_ROOT/.compose-networks"
printf '%s\n' alpha alpha >"$GAK_COMPOSE_SERVICES_ROOT/lab/.compose-stop-order"
reject 'duplicate entry'
printf '%s\n' beta alpha >"$GAK_COMPOSE_SERVICES_ROOT/lab/.compose-stop-order"
printf '%s\n' lab relay batch >"$GAK_COMPOSE_SERVICES_ROOT/.compose-autostart"
reject 'cannot be autostarted'

printf '%s\n' 'lifecycle instance fixture: passed'
