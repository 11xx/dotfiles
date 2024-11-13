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

ghcup_remove_bin_dir_from_path() {
    export PATH=$(printf '%s\n' "$PATH" | sed "s,${GHCUP_BIN_DIR}:,,")
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
