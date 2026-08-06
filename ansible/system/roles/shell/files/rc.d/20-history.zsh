# Managed by Ansible (role: shell) — edit the role, not this file.
#
# History lives under XDG state rather than $HOME so it survives config resets
# and is obviously not configuration. Atuin keeps the searchable copy; this file
# is the plain-text fallback for when atuin is missing or a shell starts before
# it initialises, so the limits are set high enough to make it a real archive.

: "${XDG_STATE_HOME:=$HOME/.local/state}"
[[ -d $XDG_STATE_HOME/zsh ]] || mkdir -p "$XDG_STATE_HOME/zsh"

export HISTFILE=$XDG_STATE_HOME/zsh/history
export HISTSIZE=10000000
export SAVEHIST=10000000

setopt histignorealldups
