#!/usr/bin/echo 'This is a source only file.'
is_command prepend_path &&
    prepend_path "${XDG_BIN_HOME%/*}/ghcup-bin"

export GHCUP_USE_XDG_DIRS=t # https://www.haskell.org/ghcup/guide/#xdg-support

alias ghcup='XDG_BIN_HOME="${XDG_BIN_HOME%/*}/ghcup-bin" ghcup'
