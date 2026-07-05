#!/usr/bin/echo 'This is a source only file.'
PASSWORD_STORE_MAIN_DIR="${PASSWORD_STORE_MAIN_DIR:-$HOME/.password-store}"
PASSWORD_STORE_SECONDARY_DIR="${PASSWORD_STORE_SECONDARY_DIR:-$HOME/.password-store-secondary}"

pass-main () {
    PASSWORD_STORE_DIR="${PASSWORD_STORE_MAIN_DIR}" command pass "$@"
}

pass-secondary () {
    PASSWORD_STORE_DIR="${PASSWORD_STORE_SECONDARY_DIR}" command pass "$@"
}

pass-dev () {
    pass-secondary "$@"
}

if [ -n "${ZSH_VERSION:-}" ] && command -v compdef >/dev/null 2>&1; then
    compdef _pass pass-main pass-secondary pass-dev
fi
