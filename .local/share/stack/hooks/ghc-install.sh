#!/bin/sh
# !! KEEP THIS SCRIPT POSIX COMPLIANT !!

# see https://docs.haskellstack.org/en/stable/configure/customisation_scripts/#ghc-installation-customisation
# for documentation about hooks

# Stack integration with GHCup
# https://www.haskell.org/ghcup/guide/#strategy-1-stack-hooks-new-recommended

set -eu

XDG_BIN_HOME=${XDG_BIN_HOME:-$HOME/.local/bin}
export GHCUP_BIN_DIR=${XDG_BIN_HOME%/*}/ghcup-bin
__newPath=$(
    printf '%s\n' "$PATH" |
        awk -v ghcupdir=${GHCUP_BIN_DIR} \
            '{ sub(ghcupdir":", "", $0); print $0":"ghcupdir }'
         )
unset __newPath

ghcup() {
    XDG_BIN_HOME=$GHCUP_BIN_DIR ghcup "$@"
}


case $HOOK_GHC_TYPE in
    bindist)
        ghc_path=$(ghcup whereis ghc "$HOOK_GHC_VERSION" || { ghcup install ghc "$HOOK_GHC_VERSION" >/dev/null && ghcup whereis ghc "$HOOK_GHC_VERSION" ; }) || { >&2 echo "Installing $HOOK_GHC_VERSION via ghcup failed" exit 3 ;}
        printf "%s" "${ghc_path}"
        ;;
    git)
        # TODO: should be somewhat possible
        >&2 echo "Hook doesn't support installing from source"
        exit 1
        ;;
    *)
        >&2 echo "Unsupported GHC installation type: $HOOK_GHC_TYPE"
        exit 2
        ;;
esac
