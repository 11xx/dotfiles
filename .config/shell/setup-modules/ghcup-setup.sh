#!/usr/bin/echo 'This is a source only file.'
! is_command ghcup && {
    printf '%s: ghcup not found. Skipping...\n' "$0" >&2
    exit 1
}

GHCUP_BIN_DIR=${XDG_BIN_HOME%/*}/ghcup-bin

is_command prepend_path &&
    prepend_path "${XDG_BIN_HOME%/*}/ghcup-bin"

__newPath=$(
    printf '%s\n' "$PATH" |
        awk -v ghcupdir=${GHCUP_BIN_DIR} \
            '{ sub(ghcupdir":", "", $0); print $0":"ghcupdir }'
         )
is_command paru && # make sure variables expand.
    alias paru="PATH=\"${__newPath}\" paru"

is_command makepkg &&
    alias makepkg="PATH=\"${__newPath}\" makepkg"

unset __newPath

export GHCUP_USE_XDG_DIRS=t # https://www.haskell.org/ghcup/guide/#xdg-support

alias ghcup='XDG_BIN_HOME="$GHCUP_BIN_DIR" ghcup'
