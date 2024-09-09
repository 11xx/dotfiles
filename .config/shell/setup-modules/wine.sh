#!/usr/bin/echo 'This is a source only file.'
wineDefaultPrefixDir=${XDG_DATA_HOME}/wine/prefixes/default
/usr/bin/mkdir -p "${wineDefaultPrefixDir}"
alias winedef="WINEPREFIX=${wineDefaultPrefixDir} wine"
unset wineDefaultPrefixDir
