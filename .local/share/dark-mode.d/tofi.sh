#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

tofiDir=${XDG_CONFIG_HOME}/tofi

check_file "${tofiDir}"/config
check_file "${tofiDir}"/center-box

tofi_replace_include_theme() {
    cd "${tofiDir}" || exit 1
    sed -Ei 's/^(include=)((\.\/)?(center-box-|def-)).*/\1\2'$theme'/' config center-box
}

theme=dark

tofi_replace_include_theme
