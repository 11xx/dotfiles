#!/usr/bin/env sh
# [[file:../../../.config/darkman/README.org::*Eww mainbar][Eww mainbar:1]]
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

ewwDir=${XDG_CONFIG_HOME}/eww

# files containing css variables, the eww.scss file have to use them properly
light=light-colors.scss
dark=dark-colors.scss

# check the one that will be changed to
check_file "${ewwDir}"/"${dark}"

sed -i "s/^\(@import\) *\"${light}\".*/\1 \"${dark}\";/" \
    "${ewwDir}"/eww.scss
# Eww mainbar:1 ends here
