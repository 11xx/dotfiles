#!/usr/bin/echo 'This is a source only file.'
! is_command ghcup && {
    printf '%s: ghcup not found. Skipping...\n' "$0" >&2
    return 1
}

GHCUP_BIN_DIR=${XDG_BIN_HOME%/*}/ghcup-bin

is_command prepend_path &&
    prepend_path "${GHCUP_BIN_DIR}"

__newPath=$(
    printf '%s\n' "$PATH" |
        awk -v ghcupdir=${GHCUP_BIN_DIR} \
            '{ sub(ghcupdir":", "", $0); print $0":"ghcupdir }'
         )
is_command paru && # make sure variables expand.
    alias paru="PATH=\"${__newPath}\" paru"

is_command makepkg &&
    alias makepkg="PATH=\"${__newPath}\" makepkg"

unset __newPath

export GHCUP_USE_XDG_DIRS=t # https://www.haskell.org/ghcup/guide/#xdg-support

alias ghcup='XDG_BIN_HOME="$GHCUP_BIN_DIR" ghcup'

alias cabal='PATH="$GHCUP_BIN_DIR":"$PATH" cabal'

ghcup_remove_bin_dir_from_path() {
    export PATH=$(printf '%s\n' "$PATH" | sed "s,${GHCUP_BIN_DIR}:,,")
    unalias cabal
}

cabal_install_copy() {
    cabal install \
          --overwrite-policy=always \
          --install-method=copy \
          "$@"
}

cabal_install_copy_dir() {
    cabal_install_copy \
        --installdir="${cabalInstallDir:-dist}" \
        --enable-profiling \
        --enable-executable-profiling \
        "$@"
}

alias cinstall=cabal_install_copy
alias cidist=cabal_install_copy_dir
alias ci.='cabalInstallDir=. cabal_install_copy_dir'

alias arch-hs='arch-hs -h "$CABAL_DIR/packages/hackage.haskell.org/01-index.tar"'

export CABAL_DIR="$XDG_DATA_HOME"/cabal
export CABAL_CONFIG="$XDG_CONFIG_HOME"/cabal/config
append_path "$CABAL_DIR"/bin

export STACK_ROOT="$XDG_DATA_HOME"/stack
export STACK_XDG=1
