#!/usr/bin/env sh
check_file() {
    [ -f "$1" ] && return 0
    printf 'The file "%s" does not exist, aborting...\n' "$1"
    exit 1
}

check_cmd() {
    ! command -v "$1" > /dev/null && exit 1
}

running_check() {
    pgrep -ixU "$(id -u)" "$1" > /dev/null
}

running_check_killall() {
    running_check "$1" && killall "$1" --quiet
}

check_cmd swaybg

running_check_killall swaybg
swaybg_fork() {
    nohup swaybg --color "$@" >/dev/null 2>&1 &
    # IMPORTANT: fork this process because darkman will not kill any
    # attached process after executing.
}

swaybg_fork '#eeeeee'
