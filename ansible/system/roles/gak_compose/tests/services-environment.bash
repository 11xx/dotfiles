#!/usr/bin/env bash
# Exercises the deployed command's runtime resolution: the declared profile must
# supply the interpreter and the Compose provider whatever the caller's
# environment holds, and neither a decoy on PATH nor a hostile Python variable
# may reach the result. Nothing is pulled, created or started.
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
here=$(cd "$(dirname "$0")" && pwd)
launcher="$here/../files/gak-services"
# shellcheck source=fixture-profile.sh
. "$here/fixture-profile.sh"

fixture=$(mktemp -d "$TMPDIR/gak-services-environment.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

fail() {
    printf 'services environment fixture: %s\n' "$*" >&2
    [[ -s "$fixture/stdout" ]] && { printf -- '--- stdout ---\n' >&2; cat "$fixture/stdout" >&2; }
    [[ -s "$fixture/stderr" ]] && { printf -- '--- stderr ---\n' >&2; cat "$fixture/stderr" >&2; }
    exit 1
}

profile="$fixture/profiles/home"
system_bin="$fixture/profiles/system/bin"
privileged_bin="$fixture/privileged/bin"
decoy_bin="$fixture/decoy/bin"
empty_profile="$fixture/profiles/empty"
state="$fixture/state"
services_root="$fixture/services"
mkdir -p "$system_bin" "$privileged_bin" "$decoy_bin" "$empty_profile" "$state" \
    "$services_root" "$fixture/runtime"
: >"$state/containers.tsv"
: >"$state/images.tsv"
: >"$fixture/stdout"
: >"$fixture/stderr"

make_fixture_profile "$profile" || {
    printf '%s\n' 'services environment fixture: skipped (no python3)' >&2
    exit 77
}
if ! "$profile/bin/python3" -I -c 'import yaml' 2>/dev/null; then
    printf '%s\n' 'services environment fixture: skipped (the fixture interpreter has no PyYAML)' >&2
    exit 77
fi

# The system profile owns the ordinary tools the stand-in itself needs.
for tool in flock realpath mkdir chmod sleep cat grep sed awk mv rm sh bash pgrep; do
    if path=$(command -v "$tool" 2>/dev/null); then
        ln -sf "$path" "$system_bin/$tool"
    fi
done
# Podman is reached through the declared profile, as the Compose provider is on
# the host.
ln -sf "$here/fake-podman" "$profile/bin/podman"

# Decoys that must lose: a Podman that always fails and an interpreter that
# records any use of itself.
printf '#!/bin/sh\nexit 3\n' >"$decoy_bin/podman"
printf '#!/bin/sh\nprintf ambient >>"%s"\nexit 3\n' "$fixture/python3.used" >"$decoy_bin/python3"
chmod 0755 "$decoy_bin/podman" "$decoy_bin/python3"

project="$services_root/alpha"
mkdir -p "$project"
printf 'name: alpha\nservices:\n  alpha:\n    container_name: alpha\n    image: example.invalid/alpha:latest\n' \
    >"$project/compose.yaml"
printf 'alpha\texample.invalid/alpha:latest\talpha\n' >"$project/services.map"
printf 'example.invalid/alpha:latest\taaaaaaaaaaaa1111\n' >"$state/images.tsv"

# Runs the launcher the way a scheduled job or a bare remote invocation would:
# an environment built from nothing, holding only what the host itself sets.
run_clean() {
    local home_profile=$1 inherited_path=$2
    shift 2
    : >"$fixture/stdout"
    : >"$fixture/stderr"
    set +e
    env -i \
        HOME="$fixture" \
        ${inherited_path:+PATH="$inherited_path"} \
        TMPDIR="$TMPDIR" \
        FAKE_STATE="$state" \
        FAKE_LOG="$fixture/podman.log" \
        FAKE_DETACHED_PID="$fixture/detached.pid" \
        GAK_COMPOSE_SERVICES_ROOT="$services_root" \
        GAK_SERVICES_RUNTIME_DIR="$fixture/runtime" \
        GAK_SERVICES_HOME_PROFILE="$home_profile" \
        GAK_SERVICES_SYSTEM_PROFILE="$fixture/profiles/system" \
        GAK_SERVICES_PRIVILEGED_BIN="$privileged_bin" \
        "${EXTRA[@]}" \
        "$launcher" "$@" >"$fixture/stdout" 2>"$fixture/stderr"
    updater_status=$?
    set -e
}

EXTRA=()

# --- a wholly empty environment still reaches the declared runtime ----------

: >"$fixture/podman.log"
run_clean "$profile" "" list
((updater_status == 0)) || fail 'the declared profile did not supply the runtime'
grep -F 'alpha [stopped] services: alpha' "$fixture/stdout" >/dev/null ||
    fail 'the command did not read its project from an empty environment'
[[ ! -e "$fixture/python3.used" ]] || fail 'an ambient interpreter was consulted'

# --- a decoy earlier on PATH must not win -----------------------------------

: >"$fixture/podman.log"
run_clean "$profile" "$decoy_bin:$system_bin" list
((updater_status == 0)) || fail 'a decoy earlier on PATH displaced the declared Podman'
grep -F 'compose -f compose.yaml config' "$fixture/podman.log" >/dev/null ||
    fail 'the declared Podman was not the one invoked'
[[ ! -e "$fixture/python3.used" ]] || fail 'a competing interpreter on PATH was consulted'

# The declared directories lead, in the stated order, even when one of them was
# already present further down the inherited PATH.
: >"$fixture/podman.log"
run_clean "$profile" "$decoy_bin:$system_bin:$profile/bin" list
((updater_status == 0)) || fail 'a declared directory already on PATH was not promoted'
seen=$(cat "$state/path.seen")
expected="$privileged_bin:$profile/bin:$system_bin:$decoy_bin"
[[ $seen == "$expected"* ]] || {
    printf 'PATH the child saw: %s\nexpected prefix:    %s\n' "$seen" "$expected" >&2
    fail 'the declared directories did not lead the handed-down PATH'
}

# --- hostile interpreter and provider variables are neutralised -------------

: >"$fixture/podman.log"
EXTRA=(
    PYTHONPATH=/hostile/pythonpath
    PYTHONHOME=/hostile/pythonhome
    PYTHONSTARTUP=/hostile/startup
    GUIX_PYTHONPATH=/hostile/guixpythonpath
    PODMAN_COMPOSE_PROVIDER=/hostile/provider
    COMPOSE_PROFILES=hostile
)
run_clean "$profile" "$decoy_bin:$system_bin" list
EXTRA=()
((updater_status == 0)) || fail 'hostile interpreter variables broke the declared runtime'
[[ $(cat "$state/provider.seen") == unset ]] ||
    fail 'an inherited provider selection reached the Compose provider'
[[ $(cat "$state/profiles.seen") == unset ]] ||
    fail 'an inherited Compose profile selection reached the provider'

# The interpreter itself must not have taken the hostile module path.
env -i HOME="$fixture" PATH="$decoy_bin" \
    PYTHONPATH=/hostile/pythonpath GUIX_PYTHONPATH=/hostile/guixpythonpath \
    GAK_SERVICES_HOME_PROFILE="$profile" \
    GAK_SERVICES_IMPLEMENTATION=/dev/stdin \
    "$launcher" <<'PY' >"$fixture/syspath" 2>"$fixture/stderr" || fail 'the interpreter probe failed'
import sys
print("hostile" if any("hostile" in entry for entry in sys.path) else "clean")
PY
[[ $(cat "$fixture/syspath") == clean ]] ||
    fail 'a hostile module path reached the interpreter'

# --- refusals name what is missing ------------------------------------------

run_clean "$empty_profile" "$system_bin" list
((updater_status != 0)) || fail 'a profile with no interpreter was accepted'
grep -E 'generated environment|interpreter' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the unusable profile'

run_clean "$fixture/profiles/absent" "$system_bin" list
((updater_status != 0)) || fail 'an absent profile was accepted'
grep -F 'guix home reconfigure' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the step that creates the profile'

: >"$state/no-provider"
run_clean "$profile" "$system_bin" list
((updater_status != 0)) || fail 'a missing Compose provider was not noticed'
grep -F 'no Compose provider answered' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the Compose provider'
rm -f "$state/no-provider"

# --- an update from an empty environment still reaches the provider ---------

: >"$fixture/podman.log"
printf 'example.invalid/alpha:latest\teeeeeeeeeeee5555\n' >"$project/pull.map"
printf 'alpha\trunning\t0\taaaaaaaaaaaa1111\talpha\t%s\n' "$(realpath "$project")" \
    >"$state/containers.tsv"
EXTRA=(GAK_SERVICES_READINESS_INTERVAL=0 GAK_SERVICES_SETTLE_SECONDS=0)
run_clean "$profile" "" update alpha --timeout 5
EXTRA=()
((updater_status == 0)) || fail 'an update from an empty environment failed'
grep -F 'alpha: updated' "$fixture/stdout" >/dev/null ||
    fail 'the empty-environment update did not report its result'
grep -F 'compose -f compose.yaml up -d --force-recreate --pull never' "$fixture/podman.log" \
    >/dev/null || fail 'the empty-environment update did not recreate through the provider'
[[ ! -e "$fixture/python3.used" ]] || fail 'the update consulted an ambient interpreter'

printf '%s\n' 'services environment fixture: passed'
