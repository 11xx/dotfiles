#!/usr/bin/env sh
# [[file:../../../.config/darkman/README.org::*Dark][Dark:1]]
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
# swaybg --color '#eeeeee' &
swaybg_fork() {
    # Setting the wayland display because systemd would not recognize it otherwise. #TODO-Workarounds?
    WAYLAND_DISPLAY=wayland-1 swaybg --color "$@" & # IMPORTANT: fork this process because
                          # otherwise darkman will not execute the
                          # other scripts, waiting for this one to
                          # finish.
}

swaybg_fork '#382738'
# Dark:1 ends here
