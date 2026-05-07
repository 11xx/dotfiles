#!/usr/bin/env bash
set -euo pipefail

INIT_DIR="${HOME}/init.d"

if [[ -d "$INIT_DIR" ]]; then
  shopt -s nullglob
  for f in "$INIT_DIR"/*; do
    [[ -f "$f" && -x "$f" ]] || continue
    "$f"
  done
  shopt -u nullglob
fi

echo 'END init.sh, running provided CMD'

exec "$@"
