#!/usr/bin/env bash
set -euo pipefail

mkdir -p \
      /home/node/.config/opencode \
      /home/node/.local/share/opencode \
      /home/node/.local/state/opencode \
      /workspace

cd /workspace
exec "$@"
