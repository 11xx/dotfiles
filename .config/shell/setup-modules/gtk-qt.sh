#!/usr/bin/echo 'This is a source only file.'
export QT_QPA_PLATFORMTHEME=kde

# export GTK_USE_PORTAL=1

is_command prepend_path &&
    prepend_path "${XDG_DATA_HOME}/qt-platform-theme-wrappers"
