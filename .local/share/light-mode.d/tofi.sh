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

tofiDir=${XDG_CONFIG_HOME}/tofi

check_file "${tofiDir}"/config
check_file "${tofiDir}"/center-box

tofi_replace_include_theme() {
    cd "${tofiDir}" || exit 1
    sed -Ei 's/^(include=)((\.\/)?(center-box-|def-)).*/\1\2'$theme'/' config center-box
}

theme=light

tofi_replace_include_theme
