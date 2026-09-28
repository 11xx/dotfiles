# Managed by Ansible (role: shell) — edit the role, not this file.
#
# Base aliases for ak. Its .zshrc can override them.

# Listing. `l` is the everyday one; `lo` keeps the owner column for when it
# matters, which on a shared media tree is more often than on a laptop.
if (( $+commands[eza] )); then
    alias l='eza -la --no-user --color=auto --group-directories-first --time-style long-iso'
    alias lo='eza -lag --color=auto --group-directories-first --time-style long-iso'
    alias lt='l -T'
else
    alias l='ls -la --color=auto --group-directories-first'
    alias lo='ls -la --color=auto'
fi

# Interactive by default, so a mistyped glob asks before it destroys anything.
# advcpmv's cpg/mvg add a progress bar; they are an Arch-only extra, hence probed.
if (( $+commands[cpg] && $+commands[mvg] )); then
    alias cp='cpg -vi --progress-bar'
    alias mv='mvg -vi --progress-bar'
else
    alias cp='cp -vi'
    alias mv='mv -vi'
fi

alias mkdir='mkdir -pv'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

alias cdc='cd "$XDG_CONFIG_HOME"'
alias cds='cd "$XDG_DATA_HOME"'
alias cdcc='cd "$XDG_CACHE_HOME"'
alias cdst='cd "$XDG_STATE_HOME"'

alias f='fzf'
alias b='bat'

# The dotfiles bare repo. Same layout on every host that has a checkout.
alias dot='git --git-dir="$HOME/.local/dotfiles.git" --work-tree="$HOME"'
