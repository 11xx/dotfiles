#!/bin/sh
set -eu

hook=${0##*/}
fd=${GAK_HUB_LOCK_FD:-}
slot=${GAK_HUB_CONFIG_BASE:-}
case "$fd:$slot" in
    *[!0-9:]*|:*|*:) exit 1 ;;
esac
[ "$fd" -ge 3 ] && [ "$fd" -le 255 ] && [ "$slot" -lt 32 ] || exit 1

repository=${GIT_DIR:-.}
original="$repository/hooks/$hook"
[ -x "$original" ] || exit 0

(
    eval "exec ${fd}>&-"
    eval "unset GIT_CONFIG_KEY_${slot} GIT_CONFIG_VALUE_${slot}"
    GIT_CONFIG_COUNT=$slot
    export GIT_CONFIG_COUNT
    unset GAK_HUB_LOCK_FD GAK_HUB_CONFIG_BASE
    exec "$original" "$@"
)
