#!/usr/bin/env bash
# Reads real Compose definitions through the real provider, so the updater's
# strict reader is exercised against the normalization it actually receives
# rather than against a hand-written imitation of it. Nothing is pulled,
# created or started: only `podman compose config` runs.
set -Eeuo pipefail

: "${TMPDIR:=/tmp}"
here=$(cd "$(dirname "$0")" && pwd)
updater=${GAK_SERVICES_TEST_COMMAND:-"$here/run-updater"}

if ! command -v podman >/dev/null; then
    printf '%s\n' 'provider fixture: skipped (no podman)' >&2
    exit 77
fi
probe=$(mktemp -d "$TMPDIR/gak-services-provider-probe.XXXXXXXX")
printf 'name: probe\nservices:\n  probe:\n    image: example.invalid/probe:latest\n' \
    >"$probe/compose.yaml"
if ! ( cd "$probe" && podman compose -f compose.yaml config >/dev/null 2>&1 ); then
    rm -rf -- "$probe"
    printf '%s\n' 'provider fixture: skipped (no working Compose provider)' >&2
    exit 77
fi
rm -rf -- "$probe"

fixture=$(mktemp -d "$TMPDIR/gak-services-provider.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

fail() {
    printf 'provider fixture: %s\n' "$*" >&2
    [[ -s "$fixture/stdout" ]] && { printf -- '--- stdout ---\n' >&2; cat "$fixture/stdout" >&2; }
    [[ -s "$fixture/stderr" ]] && { printf -- '--- stderr ---\n' >&2; cat "$fixture/stderr" >&2; }
    exit 1
}

# shellcheck source=fixture-profile.sh
. "$here/fixture-profile.sh"
make_fixture_profile "$fixture/profile" || {
    printf '%s\n' 'provider fixture: skipped (no python3)' >&2
    exit 77
}
if ! "$fixture/profile/bin/python3" -I -c 'import yaml' 2>/dev/null; then
    printf '%s\n' 'provider fixture: skipped (the fixture interpreter has no PyYAML)' >&2
    exit 77
fi
export GAK_SERVICES_HOME_PROFILE="$fixture/profile"

export FAKE_STATE="$fixture/state"
export FAKE_LOG="$fixture/podman.log"
export FAKE_DETACHED_PID="$fixture/detached.pid"
export FAKE_REAL_PODMAN=podman
export GAK_COMPOSE_PODMAN="$here/fake-podman"
export GAK_SERVICES_RUNTIME_DIR="$fixture/runtime"
export GAK_COMPOSE_SERVICES_ROOT="$fixture/services"
mkdir -p "$FAKE_STATE" "$fixture/runtime" "$GAK_COMPOSE_SERVICES_ROOT"
: >"$FAKE_STATE/containers.tsv"
: >"$FAKE_STATE/images.tsv"
: >"$FAKE_LOG"
: >"$fixture/stdout"
: >"$fixture/stderr"

hook="$fixture/hook"
printf '#!/bin/sh\nexit 0\n' >"$hook"
chmod 0755 "$hook"

project="$GAK_COMPOSE_SERVICES_ROOT/reader"
mkdir -p "$project"
cat >"$project/compose.yaml" <<EOF
name: reader
x-update:
  before-update:
    - $hook
    - two words
  readiness:
    - $hook
  readiness-timeout: 45

services:
  frontend:
    image: example.invalid/frontend:latest
    container_name: reader-frontend
    environment:
      APPLICATION_TOKEN: fixture-shibboleth
  manual:
    image: example.invalid/manual:latest
    container_name: reader-manual
    profiles:
      - manual
EOF

run_updater() {
    : >"$fixture/stdout"
    : >"$fixture/stderr"
    set +e
    "$updater" "$@" >"$fixture/stdout" 2>"$fixture/stderr"
    updater_status=$?
    set -e
}

run_updater list
((updater_status == 0)) || fail 'the provider-normalized definition was rejected'
grep -F 'reader [stopped] services: frontend' "$fixture/stdout" >/dev/null ||
    fail 'the active service set was not read through the provider'
! grep -F 'manual' "$fixture/stdout" >/dev/null ||
    fail 'a profile-gated service was treated as part of the project'
grep -F "before-update: $hook" "$fixture/stdout" >/dev/null ||
    fail 'the extension was not read through the provider'
grep -F '(timeout 45s)' "$fixture/stdout" >/dev/null ||
    fail 'the declared readiness timeout was not read'
! grep -F 'fixture-shibboleth' "$fixture/stdout" "$fixture/stderr" >/dev/null ||
    fail 'an expanded Compose environment reached the output'

# The provider escapes a value the reader deliberately refuses, so the refusal
# happens on the provider's own encoding rather than on raw source text.
cat >"$project/compose.yaml" <<EOF
name: reader
x-update:
  before-update:
    - $hook
    - "a\tb"
services:
  frontend:
    image: example.invalid/frontend:latest
EOF
run_updater list
((updater_status != 0)) || fail 'a control character in an extension value was accepted'
grep -F 'holds a control character or line break' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the offending encoding'

# An undefined interpolation becomes an empty argument rather than an error.
cat >"$project/compose.yaml" <<EOF
name: reader
x-update:
  before-update:
    - $hook
    - \${GAK_SERVICES_UNDEFINED_PROBE}
services:
  frontend:
    image: example.invalid/frontend:latest
EOF
run_updater list
((updater_status != 0)) || fail 'an undefined interpolation was accepted'
grep -F 'argument 2 is empty' "$fixture/stderr" >/dev/null ||
    fail 'the empty argument was not named'

# A policy of the wrong shape survives provider normalization and must be
# refused on the provider's own output, not on raw source text.
cat >"$project/compose.yaml" <<EOF
name: reader
x-update: broken
services:
  frontend:
    image: example.invalid/frontend:latest
EOF
run_updater list
((updater_status != 0)) || fail 'a scalar update policy was accepted'
grep -F 'x-update is not a mapping' "$fixture/stderr" >/dev/null ||
    fail 'the refusal did not name the malformed policy'

# A duplicate key is resolved by the provider before the reader sees it; what
# matters is that whatever survives is validated rather than assumed.
cat >"$project/compose.yaml" <<EOF
name: reader
x-update:
  before-update:
    - $hook
x-update:
  before-update: 7
services:
  frontend:
    image: example.invalid/frontend:latest
EOF
run_updater list
((updater_status != 0)) || fail 'a duplicate policy key left an unvalidated policy'
grep -F 'is not a non-empty list' "$fixture/stderr" >/dev/null ||
    fail 'the surviving duplicate was not validated'

printf '%s\n' 'provider fixture: passed'
