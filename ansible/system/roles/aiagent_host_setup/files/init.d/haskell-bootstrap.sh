#!/usr/bin/env bash
set -euo pipefail

GHCUP_BIN="$HOME/.ghcup/bin/ghcup"

if [[ ! -x "$GHCUP_BIN" ]]; then
    echo "[init] Bootstrapping Haskell toolchain..."

    # see options https://github.com/haskell/ghcup-hs/blob/master/scripts/bootstrap/bootstrap-haskell
    export BOOTSTRAP_HASKELL_NONINTERACTIVE=1   # suppress all prompts
    export BOOTSTRAP_HASKELL_INSTALL_HLS=1      # HLS is opt-in even in noninteractive
    export BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1 # omit Stack
    export BOOTSTRAP_HASKELL_STACK_SETUP=1      # stack/ghcup integration
    export BOOTSTRAP_HASKELL_GHC_VERSION=recommended
    export BOOTSTRAP_HASKELL_CABAL_VERSION=recommended
    # BOOTSTRAP_HASKELL_ADJUST_BASHRC must be UNSET (not empty) to suppress
    # .bashrc modification in noninteractive mode — unset is the default
    unset BOOTSTRAP_HASKELL_ADJUST_BASHRC

    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh

    if [[ -f "$HOME/.ghcup/env" ]]; then
        . "$HOME/.ghcup/env"
    fi

    cabal update --ignore-project
    echo "[init] Haskell toolchain ready."
else
    if [[ -f "$HOME/.ghcup/env" ]]; then
        . "$HOME/.ghcup/env"
    fi

    cabal update --ignore-project
    echo "[init] Haskell toolchain already present, skipping."
fi
