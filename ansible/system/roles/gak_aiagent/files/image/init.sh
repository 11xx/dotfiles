#!/usr/bin/env bash
set -euo pipefail

for script in /usr/local/share/aiagent/init.d/*; do
    [[ -x $script ]] || continue
    "$script" "$@"
done

exec "$@"
