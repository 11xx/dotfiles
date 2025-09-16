#!/usr/bin/echo 'This is a source only file.'
append_path "$XDG_DATA_HOME/npm/bin"
export NPM_CONFIG_USERCONFIG="$XDG_CONFIG_HOME"/npm/npmrc
export npm_config_devdir="$XDG_CACHE_HOME"/gyp # https://github.com/nodejs/node-gyp
export NVM_DIR="$XDG_DATA_HOME"/nvm
