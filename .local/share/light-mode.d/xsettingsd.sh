#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

xsettingsdConf=${XDG_CONFIG_HOME:-$HOME/.config}/xsettingsd/xsettingsd.conf

check_file "${xsettingsdConf}"

trap 'running_check xsettingsd && killall -HUP xsettingsd' EXIT INT

themeName=Adwaita

sed -i "s|^\(Net/ThemeName\).*|\1 \"${themeName}\"|" "${xsettingsdConf}"
