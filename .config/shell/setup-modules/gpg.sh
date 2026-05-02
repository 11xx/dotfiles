#!/usr/bin/echo 'This is a source only file.'
[ ! -d "${GNUPGHOME}" ] &&
    mkdir -p -m 700 "${GNUPGHOME}"

if [[ -o interactive ]] && [[ -t 0 ]]; then
    export GPG_TTY=$(tty)
    gpg-connect-agent updatestartuptty /bye >/dev/null
fi
