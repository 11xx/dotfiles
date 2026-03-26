#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

check_cmd swaybg

running_check_killall swaybg
swaybg_fork() {
    nohup swaybg --color "$@" >/dev/null 2>&1 &
    # IMPORTANT: fork this process because darkman will not kill any
    # attached process after executing.
}

swaybg_fork '#eeeeee'
