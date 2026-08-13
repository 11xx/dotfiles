#!/usr/bin/echo 'This is a source only file.'
check_domain() {
    [ "$#" -gt 0 ] || { echo 'usage: check_domain <domain>...' >&2; return 2; }
    __ckdom_ok='' __ckdom_warn='' __ckdom_off=''
    if [ -t 1 ]; then
        __ckdom_ok=$(printf '\033[32m')
        __ckdom_warn=$(printf '\033[33m')
        __ckdom_off=$(printf '\033[0m')
    fi
    for __ckdom_d in "$@"; do
        case $(curl -sL -o /dev/null -w '%{http_code}' -m 20 \
                    "https://rdap.org/domain/${__ckdom_d}") in
            404) __ckdom_msg="${__ckdom_ok}AVAILABLE${__ckdom_off}" ;;
            200) __ckdom_msg='registered' ;;
            *)   __ckdom_msg="${__ckdom_warn}unknown${__ckdom_off}" ;;
        esac
        printf '%-28s %s\n' "$__ckdom_d" "$__ckdom_msg"
    done
    unset __ckdom_d __ckdom_msg __ckdom_ok __ckdom_warn __ckdom_off
}
