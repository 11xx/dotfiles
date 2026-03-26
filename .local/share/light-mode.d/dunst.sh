#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

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

override_dunstrc "${dunstrcLight}"
