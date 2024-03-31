if [[ $TERM == "dumb" ]] || [[ -n $INSIDE_EMACS ]]; then
    # NOTE: set this on BOTH `.zshrc' AND `.zshenv'
    unsetopt zle
    PS1='$ '
    export HISTFILE=$HOME/.tramp_history
    return
fi

[[ $- != *i* ]] && return

export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
