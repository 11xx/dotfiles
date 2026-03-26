#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

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
