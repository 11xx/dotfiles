#!/usr/bin/echo 'This is a source only file.'
[ ! -d "${GNUPGHOME}" ] &&
    mkdir -p -m 700 "${GNUPGHOME}"

GPG_TTY=$(tty)
export GPG_TTY
