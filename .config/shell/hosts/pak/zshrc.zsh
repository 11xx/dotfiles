[[ $- == *i* ]] || return

if [[ $TERM == dumb || -n $INSIDE_EMACS ]]; then
    unsetopt zle
    PS1='$ '
    return
fi

PS1='%n@%m:%~%# '

: "${XDG_STATE_HOME:=$HOME/.local/state}"
[[ -d $XDG_STATE_HOME/zsh ]] || mkdir -p "$XDG_STATE_HOME/zsh"
HISTFILE=$XDG_STATE_HOME/zsh/history
HISTSIZE=10000000
SAVEHIST=10000000
setopt histignorealldups

autoload -Uz compinit
compinit

bindkey -e
autoload -U select-word-style
select-word-style B

bindkey '^[^?' backward-kill-word
bindkey '^[^H' backward-kill-word
bindkey '^[d' kill-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"
