#!/usr/bin/echo 'This is a source only file.'
! is_command ghcup && {
    printf '%s: ghcup not found. Skipping...\n' "$0" >&2
    return 1
}

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
