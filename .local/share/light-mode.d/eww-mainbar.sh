#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh


ewwDir=${XDG_CONFIG_HOME}/eww

# files containing css variables, the eww.scss file have to use them properly
light=light-colors.scss
dark=dark-colors.scss

# check if the scss files exist
check_file "${ewwDir}"/"${light}"
check_file "${ewwDir}"/"${dark}"

eww_scss_source_theme() {
    case "$1" in
        dark) themeFile="${dark}" ;;
        light) themeFile="${light}" ;;
    esac

    sed -i "s/^\(@import\) *\"\(${light}\|${dark}\)\".*/\1 \"${themeFile}\";/" \
        "${ewwDir}"/eww.scss
}

eww_scss_source_theme light
