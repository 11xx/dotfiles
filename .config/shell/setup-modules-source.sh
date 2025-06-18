#!/usr/bin/echo 'This is a source only file.'
__setupModulesDir=$XDG_CONFIG_HOME/shell/setup-modules
if test -d "${__setupModulesDir}"; then
    for module in "${__setupModulesDir}"/*.sh \
                  "${__setupModulesDir}"/*.bash; do
        test -r "$module" && . "$module"
    done
    unset module
fi
unset __setupModulesDir
