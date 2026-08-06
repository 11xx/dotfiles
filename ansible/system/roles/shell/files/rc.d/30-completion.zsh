# Managed by Ansible (role: shell) — edit the role, not this file.

zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' menu select=0
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# Case-insensitive, then partial-word, then substring — tried in that order, so
# an exact-case match still wins when one exists.
zstyle ':completion:*' matcher-list '' \
    'm:{a-zA-Z}={A-Za-z}' \
    'r:|[._-]=* r:|=*' \
    'l:|=* r:|=*'

# Completions the user drops in by hand, and any a tool generates for itself.
: "${XDG_DATA_HOME:=$HOME/.local/share}"
localFPATH=$XDG_DATA_HOME/zsh/functions
[[ -d $localFPATH ]] || mkdir -p "$localFPATH"
fpath+="$localFPATH"

shellCompletionDir=$XDG_DATA_HOME/shell-completion
[[ -d $shellCompletionDir/zsh ]] && fpath+="$shellCompletionDir/zsh"

_comp_options+=(globdots)   # offer dotfiles without a leading dot typed

autoload -Uz compinit && compinit
autoload -U +X bashcompinit && bashcompinit

# bash-format completions have to wait for bashcompinit above.
if [[ -d $shellCompletionDir/bash ]]; then
    for _completion in "$shellCompletionDir"/bash/*(N.); do
        source "$_completion"
    done
    unset _completion
fi
