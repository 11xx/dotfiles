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

xsettingsdConf=${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf

check_file "${xsettingsdConf}"

trap 'running_check xsettingsd && killall -HUP xsettingsd' EXIT INT

themeName=Adwaita-dark

sed -i "s|^\(Net/ThemeName\).*|\1 \"${themeName}\"|" "${xsettingsdConf}"
