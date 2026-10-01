#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

check_cmd mako
check_cmd busctl

# Using busctl directly since makoctl is a script and it's buggy 2024-09-04
mako_set_mode() {
    busctl --user call \
           org.freedesktop.Notifications \
           /fr/emersion/Mako \
           fr.emersion.Mako \
           -- \
           SetMode s "$1"
}

mako_reload() {
    busctl --user call org.freedesktop.Notifications /fr/emersion/Mako fr.emersion.Mako -- Reload
}

makoDir=${XDG_CONFIG_HOME}/mako

# mako themes
light=light-mode
dark=dark-mode

check_file "${makoDir}"/"${light}"
check_file "${makoDir}"/"${dark}"

mako_source_theme() {
    case "$1" in
        dark) themeFile="${dark}" ;;
        light) themeFile="${light}" ;;
    esac

    sed -E -i "s,^(include=)(~/.config/mako|${makoDir})/(${light}|${dark}),\1\2/${themeFile}," \
        "${makoDir}"/config
}

trap 'mako_reload' EXIT INT

mako_set_mode light
mako_source_theme light
