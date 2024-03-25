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

check_cmd dunst

dunstrc="${XDG_CONFIG_HOME}"/dunst/dunstrc
dunstrcLight="${dunstrc}"-light
dunstrcDark="${dunstrc}"-dark

check_file "${dunstrcLight}"
check_file "${dunstrcDark}"

running_check_killall dunst
trap 'running_check dunst || dunst &' EXIT INT

override_dunstrc() {
    # use full path to cp to skip any aliases
    /usr/bin/cp --force "$1" "${dunstrc}"
}

override_dunstrc "${dunstrcDark}"
# Dark:1 ends here
