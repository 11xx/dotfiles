# Managed by Ansible (role: shell) — edit the role, not this file.
#
# Powerlevel10k's instant prompt replays a cached prompt before the rest of the
# shell has loaded, so it must run before anything that writes to the terminal
# or reads from it. That is why this is the first fragment: anything needing a
# password or a [y/n] answer has to go in .zshrc above the rc.d loop.
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

if [[ -r ${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
