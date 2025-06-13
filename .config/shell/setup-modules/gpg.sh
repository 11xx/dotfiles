#!/usr/bin/echo 'This is a source only file.'
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
mkdir -p -m 700 "$GNUPGHOME"

GPG_TTY=$(tty)
export GPG_TTY
