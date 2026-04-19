#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

xsettingsdConf=${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf

reload_xsettingsd() {
    running_check xsettingsd && killall -HUP xsettingsd
}

xsettingsd_link_theme() {
    (
        cd "$(dirname "${xsettingsdConf}")"
        ln -sf xsettingsd.conf."$1" xsettingsd.conf
    )
}

trap 'reload_xsettingsd' EXIT HUP INT QUIT TERM

xsettingsd_link_theme dark
