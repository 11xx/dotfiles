#!/usr/bin/env bash
# Exercise the built package with no profile initialization or ambient Python.
set -Eeuo pipefail
here=$(cd "$(dirname "$0")" && pwd)
if [[ -z ${GAK_SERVICES_TEST_COMMAND:-} ]]; then
    command -v guix >/dev/null || exit 77
    package=$(guix build --no-offload -f "$here/../files/gak-services.scm")
    GAK_SERVICES_TEST_COMMAND="$package/bin/gak-services"
fi
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/decoy" "$fixture/state" "$fixture/services/probe"
printf '#!/bin/sh\nexit 99\n' >"$fixture/decoy/python3"
chmod +x "$fixture/decoy/python3"
env -i HOME="$fixture" PATH="$fixture/decoy" \
    PYTHONHOME=/absent PYTHONPATH=/absent GUIX_PYTHONPATH=/absent \
    "$GAK_SERVICES_TEST_COMMAND" --help >/dev/null

printf 'name: probe\nservices:\n  probe:\n    image: example.invalid/probe:latest\n' \
    >"$fixture/services/probe/compose.yaml"
: >"$fixture/state/containers.tsv"
: >"$fixture/state/images.tsv"
env -i HOME="$fixture" PATH="$fixture/decoy:/usr/bin:/bin" \
    PYTHONHOME=/absent PYTHONPATH=/absent GUIX_PYTHONPATH=/absent \
    GAK_COMPOSE_PODMAN="$here/fake-podman" \
    GAK_COMPOSE_SERVICES_ROOT="$fixture/services" \
    FAKE_STATE="$fixture/state" FAKE_LOG="$fixture/log" \
    FAKE_DETACHED_PID="$fixture/detached" \
    "$GAK_SERVICES_TEST_COMMAND" list >"$fixture/output"
grep -F 'probe [stopped] services: probe' "$fixture/output" >/dev/null
! grep -E 'compose .* (pull|up)' "$fixture/log"
printf '%s\n' 'packaged environment fixture: passed'
