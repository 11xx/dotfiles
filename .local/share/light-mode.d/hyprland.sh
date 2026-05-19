#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

hyprDir=${XDG_CONFIG_HOME}/hypr
themeConfFile=${hyprDir}/themes/theme.lua

check_file "${themeConfFile}".light
check_file "${themeConfFile}".dark

hyprland_link_theme() {
    (
        cd "$(dirname "${themeConfFile}")"
        ln -sf theme.lua."$1" active-theme.lua
    )
}

hyprland_link_theme light
hyprctl eval 'apply_theme()'
