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

hyprDir=${XDG_CONFIG_HOME}/hypr
themeConfFile=${hyprDir}/themes/theme.conf

lightFile=00-light-theme.conf
darkFile=00-dark-theme.conf

check_file "${themeConfFile}"
check_file "${themeConfFile%/*}/${lightFile}"
check_file "${themeConfFile%/*}/${darkFile}"

hyprland_source_theme() {
    case "$1" in
        dark) themeFile=${darkFile} ;;
        light) themeFile=${lightFile} ;;
    esac

    sed -Ei "s,^source([[:blank:]]+|)=([[:blank:]]+|)(${lightFile}|${darkFile})$,source = ${themeFile}," "${themeConfFile}"
}

hyprland_source_theme light
