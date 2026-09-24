#!/usr/bin/env bash
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
here=$(cd "$(dirname "$0")" && pwd)
updater=${GAK_SERVICES_TEST_COMMAND:-"$here/run-updater"}
fixture=$(mktemp -d "$TMPDIR/gak-services-update.XXXXXXXX")
cleanup_fixture() {
    if [[ -f "$fixture/detached.pid" ]]; then
        kill "$(cat "$fixture/detached.pid")" 2>/dev/null || true
    fi
    rm -rf -- "$fixture"
}
trap cleanup_fixture EXIT

fail() {
    printf 'services update fixture: %s\n' "$*" >&2
    [[ -s "$fixture/stdout" ]] && { printf -- '--- stdout ---\n' >&2; cat "$fixture/stdout" >&2; }
    [[ -s "$fixture/stderr" ]] && { printf -- '--- stderr ---\n' >&2; cat "$fixture/stderr" >&2; }
    [[ -s "$fixture/podman.log" ]] && { printf -- '--- podman ---\n' >&2; cat "$fixture/podman.log" >&2; }
    exit 1
}

# shellcheck source=fixture-profile.sh
. "$here/fixture-profile.sh"
make_fixture_profile "$fixture/profile" || {
    printf '%s\n' 'services update fixture: skipped (no python3)' >&2
    exit 77
}
if ! "$fixture/profile/bin/python3" -I -c 'import yaml' 2>/dev/null; then
    printf '%s\n' 'services update fixture: skipped (the fixture interpreter has no PyYAML)' >&2
    exit 77
fi

export FAKE_STATE="$fixture/state"
export FAKE_LOG="$fixture/podman.log"
export FAKE_DETACHED_PID="$fixture/detached.pid"
export GAK_COMPOSE_PODMAN="$here/fake-podman"
export GAK_SERVICES_HOME_PROFILE="$fixture/profile"
export GAK_SERVICES_RUNTIME_DIR="$fixture/runtime"
export GAK_SERVICES_READINESS_INTERVAL=0
export GAK_SERVICES_SETTLE_SECONDS=0

reset_fixture() {
    rm -rf -- "$FAKE_STATE" "$fixture/runtime" "$fixture/roots"
    mkdir -p "$FAKE_STATE" "$fixture/runtime" "$fixture/roots"
    : >"$FAKE_STATE/containers.tsv"
    : >"$FAKE_STATE/images.tsv"
    : >"$FAKE_LOG"
    : >"$fixture/stdout"
    : >"$fixture/stderr"
}

# write_project DIR NAME SERVICE|IMAGE|CONTAINER...
write_project() {
    local dir=$1 name=$2 spec service image container
    shift 2
    mkdir -p "$dir"
    {
        printf 'name: %s\nservices:\n' "$name"
        for spec in "$@"; do
            IFS='|' read -r service image container <<<"$spec"
            printf '  %s:\n    container_name: %s\n    image: %s\n' "$service" "$container" "$image"
        done
    } >"$dir/compose.yaml"
    : >"$dir/services.map"
    for spec in "$@"; do
        IFS='|' read -r service image container <<<"$spec"
        printf '%s\t%s\t%s\n' "$service" "$image" "$container" >>"$dir/services.map"
    done
}

add_extension() {
    local dir=$1
    shift
    printf 'x-update:\n' >>"$dir/compose.yaml"
    printf '%s\n' "$@" >>"$dir/compose.yaml"
}

seed_image() {
    printf '%s\t%s\n' "$1" "$2" >>"$FAKE_STATE/images.tsv"
}

# Marks every service of a project running on the image its reference resolves
# to now, as an ordinary boot would leave it.
start_project() {
    local dir=$1 service image container id
    while IFS=$'\t' read -r service image container; do
        [[ -n $service ]] || continue
        id=$(awk -F'\t' -v ref="$image" '$1 == ref { print $2 }' "$FAKE_STATE/images.tsv")
        [[ -n $id ]] || fail "start_project without a seeded image: $image"
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$container" running 0 "$id" "$service" "$(realpath "$dir")" \
            >>"$FAKE_STATE/containers.tsv"
    done <"$dir/services.map"
}

add_container() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" 0 "$3" "$4" "$5" >>"$FAKE_STATE/containers.tsv"
}

run_updater() {
    : >"$fixture/stdout"
    : >"$fixture/stderr"
    set +e
    "$updater" "$@" >"$fixture/stdout" 2>"$fixture/stderr"
    updater_status=$?
    set -e
}

out_has() { grep -F -- "$1" "$fixture/stdout" >/dev/null || fail "stdout lacks: $1"; }
err_has() { grep -F -- "$1" "$fixture/stderr" >/dev/null || fail "stderr lacks: $1"; }
log_has() { grep -F -- "$1" "$FAKE_LOG" >/dev/null || fail "podman log lacks: $1"; }
log_lacks() { ! grep -F -- "$1" "$FAKE_LOG" >/dev/null || fail "podman log unexpectedly has: $1"; }

# --- discovery of an unfamiliar project, and stopped projects ---------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/batch:8 bbbbbbbbbbbb2222
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/batch" batch 'batch|example.invalid/batch:8|batch'
start_project "$root/alpha"
run_updater list
((updater_status == 0)) || fail 'list failed on a fresh services root'
out_has 'alpha [running]'
out_has 'batch [stopped]'
log_lacks 'compose -f compose.yaml pull'

# A project nobody told the updater about is discovered from the root alone.
write_project "$root/newcomer" newcomer 'newcomer|example.invalid/newcomer:latest|newcomer'
seed_image example.invalid/newcomer:latest cccccccccccc3333
start_project "$root/newcomer"
run_updater list
out_has 'newcomer [running]'

run_updater update batch
((updater_status != 0)) || fail 'a stopped project was updated'
err_has 'project batch is not running'
log_lacks 'compose -f compose.yaml pull'

run_updater update nothing-here
((updater_status != 0)) || fail 'an unknown project name was accepted'
err_has 'no Compose project named nothing-here'

# --- a container that merely shares a name is not the project ---------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_container alpha running aaaaaaaaaaaa1111 alpha /elsewhere/alpha
run_updater list
out_has 'alpha [stopped]'

# --- a project directory holding a space ------------------------------------

reset_fixture
root="$fixture/roots/my services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/spaced name" 'spaced name' 'alpha|example.invalid/alpha:latest|spaced-alpha'
start_project "$root/spaced name"
run_updater list
((updater_status == 0)) || fail 'a project path holding a space was rejected'
out_has 'spaced name [running]'
printf '%s\t%s\n' example.invalid/alpha:latest dddddddddddd4444 >"$root/spaced name/pull.map"
run_updater update 'spaced name'
((updater_status == 0)) || fail 'a project path holding a space failed to update'
out_has 'spaced name: updated'
out_has 'aaaaaaaaaaaa -> dddddddddddd'

# --- partially running projects are refused before any mutation -------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/web:latest 111111111111aaaa
seed_image example.invalid/db:17 222222222222bbbb
write_project "$root/paired" paired \
    'web|example.invalid/web:latest|paired-web' 'db|example.invalid/db:17|paired-db'
add_container paired-web running 111111111111aaaa web "$(realpath "$root/paired")"
run_updater update --all
((updater_status != 0)) || fail 'a partially running project was updated'
err_has 'repair partially running projects'
log_lacks 'compose -f compose.yaml pull'
run_updater update paired
((updater_status != 0)) || fail 'a named partially running project was updated'
log_lacks 'compose -f compose.yaml pull'

# --- a running container for an undeclared service is ambiguous -------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
add_container alpha-extra running aaaaaaaaaaaa1111 helper "$(realpath "$root/alpha")"
run_updater update alpha
((updater_status != 0)) || fail 'an undeclared running service was tolerated'
err_has 'services it does not declare'

# --- a definition the provider rejects, and a definition without an image ---

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
: >"$root/alpha/config.fail"
run_updater list
((updater_status != 0)) || fail 'a rejected definition was accepted'
err_has 'the Compose provider rejected the definition of project alpha'
rm -f "$root/alpha/config.fail"

printf 'name: alpha\nservices:\n  alpha:\n    build: .\n' >"$root/alpha/compose.yaml"
run_updater list
((updater_status != 0)) || fail 'a locally built project was accepted'
err_has 'is built locally'

printf 'name: alpha\nservices:\n  alpha:\n    container_name: alpha\n' >"$root/alpha/compose.yaml"
run_updater list
((updater_status != 0)) || fail 'a project without an image was accepted'
err_has 'names no image'

# --- x-update validation ----------------------------------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
hook="$fixture/hook"
printf '#!/bin/sh\nexit ${HOOK_STATUS:-0}\n' >"$hook"
chmod 0755 "$hook"

for case_name in unknown-key relative-path missing-command not-executable bad-timeout deep-nesting; do
    write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
    start_project "$root/alpha"
    case $case_name in
        unknown-key) add_extension "$root/alpha" '  after-update:' "  - $hook" ;;
        relative-path) add_extension "$root/alpha" '  before-update:' '  - hook' ;;
        missing-command) add_extension "$root/alpha" '  before-update:' "  - $fixture/absent" ;;
        not-executable)
            printf 'x\n' >"$fixture/plain"
            add_extension "$root/alpha" '  before-update:' "  - $fixture/plain"
            ;;
        bad-timeout) add_extension "$root/alpha" '  readiness-timeout: 0' ;;
        deep-nesting) add_extension "$root/alpha" '  before-update:' '    nested: 1' ;;
    esac
    run_updater list
    ((updater_status != 0)) || fail "an invalid x-update was accepted: $case_name"
    rm -rf -- "$root/alpha"
    : >"$FAKE_STATE/containers.tsv"
done

# A well-formed extension is accepted, including an argument holding a space.
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
add_extension "$root/alpha" '  before-update:' "  - $hook" '  - two words' \
    '  readiness:' "  - $hook" '  readiness-timeout: 30'
run_updater list
((updater_status == 0)) || fail 'a valid x-update was rejected'
out_has "before-update: $hook"
out_has '(timeout 30s)'

# --- dry run mutates nothing ------------------------------------------------

run_updater update --all --dry-run
((updater_status == 0)) || fail 'the dry run failed'
out_has 'dry run: no image was pulled'
out_has 'alpha: would update'
log_lacks 'compose -f compose.yaml pull'
log_lacks 'force-recreate'
[[ ! -f "$fixture/hook.ran" ]] || fail 'the dry run executed a hook'

# --- unchanged images are skipped, --force recreates them -------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
run_updater update --all
((updater_status == 0)) || fail 'an unchanged project failed'
out_has 'alpha: unchanged'
log_has 'compose -f compose.yaml pull'
log_lacks 'force-recreate'

run_updater update --all --force
((updater_status == 0)) || fail 'the forced update failed'
out_has 'alpha: updated'
log_has 'compose -f compose.yaml up -d --force-recreate --pull never'

# --- a changed image is pulled and recreated --------------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha
((updater_status == 0)) || fail 'a changed project failed to update'
out_has 'alpha: updated'
out_has 'alpha: aaaaaaaaaaaa -> eeeeeeeeeeee'
log_has 'compose -f compose.yaml up -d --force-recreate --pull never'

# An alias that moves onto an image already present is still a change.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/other:latest ffffffffffff6666
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest ffffffffffff6666 >"$root/alpha/pull.map"
run_updater update alpha
((updater_status == 0)) || fail 'an alias move was not treated as a change'
out_has 'alpha: aaaaaaaaaaaa -> ffffffffffff'

# --- a multi-container project with a shared image moves as one unit --------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/suite:34 111111111111aaaa
seed_image example.invalid/db:17 222222222222bbbb
write_project "$root/suite" suite \
    'suite|example.invalid/suite:34|suite' \
    'suite-cron|example.invalid/suite:34|suite-cron' \
    'db|example.invalid/db:17|suite-db'
start_project "$root/suite"
printf '%s\t%s\n' example.invalid/suite:34 333333333333cccc >"$root/suite/pull.map"
run_updater update suite
((updater_status == 0)) || fail 'the multi-container project failed to update'
out_has 'suite: updated'
out_has 'suite: 111111111111 -> 333333333333'
out_has 'suite-cron: 111111111111 -> 333333333333'
out_has 'db: 222222222222 -> 222222222222'
[[ $(grep -c 'force-recreate' "$FAKE_LOG") == 1 ]] || fail 'the project was recreated more than once'

# --- a failing pull recreates nothing ---------------------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/beta:latest bbbbbbbbbbbb2222
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/beta" beta 'beta|example.invalid/beta:latest|beta'
start_project "$root/alpha"
start_project "$root/beta"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
: >"$root/beta/pull.fail"
run_updater update --all
((updater_status != 0)) || fail 'a failing pull was hidden'
err_has 'nothing was recreated'
log_lacks 'force-recreate'

# --- a failing before-update hook stops the run before recreation -----------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/beta:latest bbbbbbbbbbbb2222
gate="$fixture/gate"
printf '#!/bin/sh\nprintf %%s "$GAK_SERVICES_PROJECT" >>"$1"\nexit 1\n' >"$gate"
chmod 0755 "$gate"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/beta" beta 'beta|example.invalid/beta:latest|beta'
add_extension "$root/alpha" '  before-update:' "  - $gate" "  - $fixture/gate.log"
start_project "$root/alpha"
start_project "$root/beta"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
printf '%s\t%s\n' example.invalid/beta:latest ffffffffffff6666 >"$root/beta/pull.map"
run_updater update --all
((updater_status != 0)) || fail 'a failing pre-update gate was hidden'
out_has 'alpha: failed: the before-update hook did not succeed'
out_has 'beta: skipped after an earlier failure'
log_lacks 'force-recreate'
[[ $(cat "$fixture/gate.log") == alpha ]] || fail 'the gate did not see its project name'

# --- runtime that moves between planning and recreation is refused ----------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/zeta:latest bbbbbbbbbbbb2222
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/zeta" zeta 'zeta|example.invalid/zeta:latest|zeta'
start_project "$root/alpha"
start_project "$root/zeta"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
printf '%s\t%s\n' example.invalid/zeta:latest ffffffffffff6666 >"$root/zeta/pull.map"
# While the first project is being recreated, somebody stops the second one.
drift="$fixture/drift"
printf '#!/bin/sh\nexec sed -i "s/^zeta\\trunning/zeta\\texited/" "$1"\n' >"$drift"
chmod 0755 "$drift"
add_extension "$root/alpha" '  before-update:' "  - $drift" "  - $FAKE_STATE/containers.tsv"
run_updater update --all
((updater_status != 0)) || fail 'a project whose runtime moved was recreated anyway'
out_has 'failed: project zeta changed its running state between planning and recreation'
[[ $(grep -c 'force-recreate' "$FAKE_LOG") == 1 ]] || fail 'the drifted project was recreated'

# --- usage refuses an empty selection ---------------------------------------

run_updater update
((updater_status == 2)) || fail 'an empty selection was not a usage error'
err_has 'name at least one project or pass --all'
run_updater update --all alpha
((updater_status == 2)) || fail 'a contradictory selection was accepted'

# --- readiness is bounded and stops the remaining projects ------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/web:latest 111111111111aaaa
seed_image example.invalid/db:17 222222222222bbbb
seed_image example.invalid/zeta:latest bbbbbbbbbbbb2222
write_project "$root/paired" paired \
    'web|example.invalid/web:latest|paired-web' 'db|example.invalid/db:17|paired-db'
write_project "$root/zeta" zeta 'zeta|example.invalid/zeta:latest|zeta'
start_project "$root/paired"
start_project "$root/zeta"
printf '%s\t%s\n' example.invalid/web:latest 333333333333cccc >"$root/paired/pull.map"
printf '%s\t%s\n' example.invalid/zeta:latest ffffffffffff6666 >"$root/zeta/pull.map"
printf 'web\n' >"$root/paired/up.only"
run_updater update --all --timeout 1
((updater_status != 0)) || fail 'an unreachable readiness state was hidden'
out_has 'paired: failed:'
grep -E 'within|bound|deadline' "$fixture/stdout" >/dev/null ||
    fail 'the readiness failure did not report a time bound'
out_has 'zeta: skipped after an earlier failure'
[[ $(grep -c 'force-recreate' "$FAKE_LOG") == 1 ]] || fail 'the run continued past a readiness failure'

# A container that keeps restarting does not count as ready.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
export GAK_SERVICES_SETTLE_SECONDS=0
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
: >"$root/alpha/up.flap"
run_updater update alpha --timeout 1
((updater_status != 0)) || fail 'a restarting container was reported ready'
out_has 'alpha: failed:'

# A declared readiness command must succeed within the bound.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
probe="$fixture/probe"
printf '#!/bin/sh\nexit 1\n' >"$probe"
chmod 0755 "$probe"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  readiness:' "  - $probe"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha --timeout 1
((updater_status != 0)) || fail 'a failing readiness command was hidden'
out_has 'alpha: failed:'

printf '#!/bin/sh\nexit 0\n' >"$probe"
run_updater update alpha --force --timeout 5
((updater_status == 0)) || fail 'a succeeding readiness command was not accepted'
out_has 'alpha: updated'

# --- one updater at a time --------------------------------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
mkdir -p "$fixture/runtime"
(
    exec 7>"$fixture/runtime/update.lock"
    flock 7
    "$updater" update --all >"$fixture/stdout" 2>"$fixture/stderr" && exit 0
    exit 1
) && fail 'a second updater ran while the lock was held'
err_has 'another gak-services update is already running'
log_lacks 'compose -f compose.yaml pull'

# The boot helper's lifecycle lock is a different file and is never taken.
[[ ! -e "$fixture/runtime/lock" ]] || fail 'the updater touched a lifecycle lock name'

# --- the update lock does not leak into a detached Podman descendant --------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
: >"$root/alpha/up.detach"
run_updater update alpha
((updater_status == 0)) || fail 'the detached-descendant setup failed'
kill -0 "$(cat "$fixture/detached.pid")" || fail 'the detached descendant did not survive the probe'
flock -n "$fixture/runtime/update.lock" true ||
    fail 'a detached Podman descendant retained the update lock'

# --- no expanded environment reaches the output -----------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
printf '    environment:\n      APPLICATION_TOKEN: fixture-shibboleth\n' >>"$root/alpha/compose.yaml"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha
((updater_status == 0)) || fail 'the secrecy case failed to update'
! grep -F 'fixture-shibboleth' "$fixture/stdout" "$fixture/stderr" >/dev/null ||
    fail 'an expanded Compose environment reached the output'

# --- a malformed update policy is refused, never stepped over ---------------

# A policy the operator wrote and the updater ignored is the failure that
# matters here, so every shape that is not the schema is an error.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
hook="$fixture/hook"
printf '#!/bin/sh\nexit 0\n' >"$hook"
chmod 0755 "$hook"

malformed() {
    local label=$1
    shift
    rm -rf -- "$root/alpha"
    : >"$FAKE_STATE/containers.tsv"
    write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
    start_project "$root/alpha"
    printf '%s\n' "$@" >>"$root/alpha/compose.yaml"
    run_updater list
    ((updater_status != 0)) || fail "a malformed x-update was accepted: $label"
}

malformed 'scalar policy' 'x-update: broken'
err_has 'x-update is not a mapping'
malformed 'list policy' 'x-update: [1, 2]'
err_has 'x-update is not a mapping'
malformed 'null policy' 'x-update: null'
err_has 'x-update is not a mapping'
malformed 'boolean hook' 'x-update:' '  before-update: true'
err_has 'is not a non-empty list'
malformed 'empty hook list' 'x-update:' '  before-update: []'
err_has 'is not a non-empty list'
malformed 'boolean timeout' 'x-update:' '  readiness-timeout: true'
err_has 'is not a whole number of seconds'
malformed 'null argument' 'x-update:' '  before-update:' "  - $hook" '  - null'
err_has 'argument 2 is not a string'
malformed 'numeric argument' 'x-update:' '  before-update:' "  - $hook" '  - 5'
err_has 'argument 2 is not a string'
malformed 'argument holding a line break' 'x-update:' '  before-update:' \
    "  - $hook" '  - "two\nlines"'
err_has 'argument 2 holds a control character or line break'
malformed 'timeout without a command' 'x-update:' '  before-update-timeout: 30'
err_has 'before-update-timeout has no before-update command'

# A unicode argument is ordinary data and stays accepted.
rm -rf -- "$root/alpha"
: >"$FAKE_STATE/containers.tsv"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\n' 'x-update:' '  before-update:' "  - $hook" '  - "caf\u00e9 r\u00e9sum\u00e9"' \
    >>"$root/alpha/compose.yaml"
run_updater list
((updater_status == 0)) || fail 'a unicode hook argument was rejected'

# --- a hook that hangs does not outlive its bound ---------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
sleeper="$fixture/sleeper"
printf '#!/bin/sh\nsleep 120\n' >"$sleeper"
chmod 0755 "$sleeper"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  before-update:' "  - $sleeper" '  before-update-timeout: 1'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
started_at=$(date +%s)
run_updater update alpha
elapsed=$(( $(date +%s) - started_at ))
((updater_status != 0)) || fail 'a hanging pre-update gate was accepted'
((elapsed < 60)) || fail "the hanging gate was not bounded: ${elapsed}s"
out_has 'alpha: failed:'
log_lacks 'force-recreate'
pgrep -f "$sleeper" >/dev/null && fail 'the hanging gate survived the updater'

# A hanging readiness command is bounded by the project deadline, not by itself.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  readiness:' "  - $sleeper"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
started_at=$(date +%s)
run_updater update alpha --timeout 2
elapsed=$(( $(date +%s) - started_at ))
((updater_status != 0)) || fail 'a hanging readiness command was accepted'
((elapsed < 60)) || fail "the hanging readiness command was not bounded: ${elapsed}s"
out_has 'alpha: failed:'
pgrep -f "$sleeper" >/dev/null && fail 'the hanging readiness command survived the updater'

# --- a recreation that keeps the old container is not an update -------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
: >"$root/alpha/up.stale"
run_updater update alpha --timeout 2
((updater_status != 0)) || fail 'a no-op recreation was reported as an update'
out_has 'is running images the plan did not choose'
! grep -F 'alpha: updated' "$fixture/stdout" >/dev/null ||
    fail 'a stale recreation was reported updated'

# --- drift introduced by the gate itself is caught --------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
mover="$fixture/mover"
printf '#!/bin/sh\nsed -i "s/aaaaaaaaaaaa1111/999999999999ffff/" "$1"\n' >"$mover"
chmod 0755 "$mover"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  before-update:' "  - $mover" "  - $FAKE_STATE/containers.tsv"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha --timeout 2
((updater_status != 0)) || fail 'runtime drift introduced by the gate was ignored'
out_has 'changed its running state while the before-update hook ran'
log_lacks 'force-recreate'

# The same for a local alias that moves while the gate runs.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
retag="$fixture/retag"
printf '#!/bin/sh\nprintf "%%s\\t%%s\\n" example.invalid/alpha:latest 777777777777dddd >"$1"\n' >"$retag"
chmod 0755 "$retag"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  before-update:' "  - $retag" "  - $FAKE_STATE/images.tsv"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha --timeout 2
((updater_status != 0)) || fail 'an alias that moved during the gate was ignored'
out_has 'changed what its image references resolve to while the before-update hook ran'
log_lacks 'force-recreate'

# --- a later failure keeps the summary of the earlier progress --------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/zeta:latest bbbbbbbbbbbb2222
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/zeta" zeta 'zeta|example.invalid/zeta:latest|zeta'
start_project "$root/alpha"
start_project "$root/zeta"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
printf '%s\t%s\n' example.invalid/zeta:latest ffffffffffff6666 >"$root/zeta/pull.map"
: >"$root/zeta/up.fail"
run_updater update --all --timeout 2
((updater_status != 0)) || fail 'a later project failure was hidden'
out_has 'alpha: updated'
out_has 'alpha: aaaaaaaaaaaa -> eeeeeeeeeeee'
out_has 'zeta: failed:'

# --- provider diagnostics are sanitized by default --------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
printf 'APPLICATION_TOKEN: fixture-shibboleth\n' >"$root/alpha/config.fail"
run_updater list
((updater_status != 0)) || fail 'a rejected definition was accepted'
! grep -F 'fixture-shibboleth' "$fixture/stdout" "$fixture/stderr" >/dev/null ||
    fail "the provider's own message reached the output"
err_has 'GAK_SERVICES_SHOW_PROVIDER_ERRORS'

GAK_SERVICES_SHOW_PROVIDER_ERRORS=1 run_updater list
((updater_status != 0)) || fail 'the opt-in diagnostic changed the verdict'
grep -F 'fixture-shibboleth' "$fixture/stderr" >/dev/null ||
    fail 'the opt-in diagnostic withheld the provider message'
unset GAK_SERVICES_SHOW_PROVIDER_ERRORS

# Hook output and arguments stay private unless explicitly requested.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
noisy="$fixture/noisy"
printf '#!/bin/sh\nprintf "gate diagnostic line\\n" >&2\nexit 1\n' >"$noisy"
chmod 0755 "$noisy"
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
add_extension "$root/alpha" '  before-update:' "  - $noisy" '  - fixture-argument-secret'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha --timeout 2
((updater_status != 0)) || fail 'a failing gate was accepted'
! grep -F 'gate diagnostic line' "$fixture/stdout" "$fixture/stderr" >/dev/null ||
    fail 'a failing hook exposed captured output'
! grep -F 'fixture-argument-secret' "$fixture/stdout" "$fixture/stderr" >/dev/null ||
    fail "a hook's arguments reached the output"

# --- explicit selection is scoped to what was named -------------------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image example.invalid/web:latest 111111111111aaaa
seed_image example.invalid/db:17 222222222222bbbb
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
write_project "$root/paired" paired \
    'web|example.invalid/web:latest|paired-web' 'db|example.invalid/db:17|paired-db'
start_project "$root/alpha"
add_container paired-web running 111111111111aaaa web "$(realpath "$root/paired")"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"

# The broken project blocks --all ...
run_updater update --all --timeout 2
((updater_status != 0)) || fail 'a partially running project did not block --all'
err_has 'repair partially running projects'
log_lacks 'compose -f compose.yaml pull'

# ... but not a targeted repair of an unrelated one, named twice.
: >"$FAKE_LOG"
run_updater update alpha alpha --timeout 2
((updater_status == 0)) || fail 'an unrelated broken project blocked a targeted update'
out_has 'alpha: updated'
[[ $(grep -c 'compose -f compose.yaml pull' "$FAKE_LOG") == 1 ]] ||
    fail 'a repeated target was pulled more than once'
[[ $(grep -c 'force-recreate' "$FAKE_LOG") == 1 ]] ||
    fail 'a repeated target was recreated more than once'
log_lacks "working_dir=$(realpath "$root/paired")"

# A hook cannot change the Compose definition underneath the update plan.
reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
changer="$fixture/change-definition"
printf '#!/bin/sh\nprintf "\\nx-extra: changed\\n" >> compose.yaml\n' >"$changer"
chmod 0755 "$changer"
add_extension "$root/alpha" '  before-update:' "  - $changer"
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest eeeeeeeeeeee5555 >"$root/alpha/pull.map"
run_updater update alpha --timeout 2
((updater_status != 0)) || fail 'definition drift was accepted'
out_has 'changed its definition'
log_lacks 'force-recreate'

# --- prepared local images keep the old image until acceptance --------------

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image localhost/candidate:1 eeeeeeeeeeee5555
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
run_updater update alpha --prepared-image alpha=eeeeeeeeeeee5555
((updater_status == 0)) || fail 'prepared image update failed'
out_has 'alpha: updated'
log_lacks 'compose -f compose.yaml pull'
log_has 'tag eeeeeeeeeeee5555 example.invalid/alpha:latest'
grep -F $'aaaaaaaaaaaa1111' "$FAKE_STATE/images.tsv" >/dev/null ||
    fail 'the previous image was removed before acceptance'
grep -F $'alpha\trunning\t0\teeeeeeeeeeee5555' "$FAKE_STATE/containers.tsv" >/dev/null ||
    fail 'the exact prepared image was not applied'

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image localhost/candidate:1 eeeeeeeeeeee5555
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
run_updater update alpha --prepared-image alpha=eeeeeeeeeeee5555 --from-stopped
((updater_status == 0)) || fail 'a quiesced project could not use its prepared image'
out_has 'alpha: updated'
log_lacks 'compose -f compose.yaml pull'

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
run_updater update alpha --prepared-image alpha=eeeeeeeeeeee5555
((updater_status != 0)) || fail 'an absent prepared image was accepted'
err_has 'prepared image for alpha is absent'
log_lacks 'compose -f compose.yaml pull'
log_lacks 'force-recreate'
log_lacks 'build'

reset_fixture
root="$fixture/roots/services"
export GAK_COMPOSE_SERVICES_ROOT="$root"
mkdir -p "$root"
seed_image example.invalid/alpha:latest aaaaaaaaaaaa1111
seed_image localhost/candidate:1 eeeeeeeeeeee5555
write_project "$root/alpha" alpha 'alpha|example.invalid/alpha:latest|alpha'
start_project "$root/alpha"
printf '%s\t%s\n' example.invalid/alpha:latest ffffffffffff7777 >"$root/alpha/up.move"
run_updater update alpha --prepared-image alpha=eeeeeeeeeeee5555
((updater_status != 0)) || fail 'image movement during apply was accepted'
out_has 'changed its image references during recreation'
! grep -F 'alpha: updated' "$fixture/stdout" >/dev/null ||
    fail 'an image moved during apply was reported accepted'
grep -F $'alpha\trunning\t0\teeeeeeeeeeee5555' "$FAKE_STATE/containers.tsv" >/dev/null ||
    fail 'a moving tag selected an image other than the prepared ID'
log_lacks 'tag eeeeeeeeeeee5555 example.invalid/alpha:latest'
grep -F $'aaaaaaaaaaaa1111' "$FAKE_STATE/images.tsv" >/dev/null ||
    fail 'the previous image was not retained after failed acceptance'

if grep -F 'sudo' "$updater" >/dev/null; then
    fail 'the updater contains a hidden sudo path'
fi

printf '%s\n' 'services update fixture: passed'
