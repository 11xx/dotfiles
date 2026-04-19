#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

tofiDir=${XDG_CONFIG_HOME}/tofi

tofi_link_theme() {
    [ -z "${theme}" ] && {
        printf '%s\n' 'tofi theme unset. Aborting...'
        exit 1
    }
    cd "${tofiDir}" || {
        printf "Couldn't cd to tofiDir=%s\n" "${tofiDir}"
        exit 1
    }

    ln -sf "${theme}" def-current-theme
}

theme=def-dark

tofi_link_theme
