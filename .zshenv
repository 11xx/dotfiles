if [[ $TERM == "dumb" ]] || [[ -n $INSIDE_EMACS ]]; then
    # NOTE: set this on BOTH `.zshrc' AND `.zshenv'
    unsetopt zle
    PS1='$ '
    export HISTFILE=$HOME/.tramp_history
    return
fi

[[ $- != *i* ]] && return

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
[[ -r "$XDG_CONFIG_HOME"/shell/profile ]] &&
    source "$XDG_CONFIG_HOME"/shell/profile

export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
