#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

hyprDir=${XDG_CONFIG_HOME}/hypr
themeConfFile=${hyprDir}/themes/theme.conf

check_file "${themeConfFile}".light
check_file "${themeConfFile}".dark

hyprland_link_theme() {
    (
        cd "$(dirname "${themeConfFile}")"
        ln -sf theme.conf."$1" theme.conf
    )
}

hyprland_link_theme light
