# Managed by Ansible (role: shell) — edit the role, not this file.
#
# Plugins are installed as plain checkouts rather than distribution packages, so
# every host resolves them from one layout and the load order below is the same
# everywhere. The order matters: syntax highlighting wraps the line editor and
# has to see the widgets it colours already defined, and history-substring-search
# rebinds keys highlighting has just hooked, so it follows.
#
# A missing plugin is skipped rather than fatal. Losing autosuggestions is a
# nuisance; failing to get a login shell on a headless box is not.
ZSH_PLUGIN_DIR=/usr/share/zsh/plugins

[[ -r $ZSH_PLUGIN_DIR/powerlevel10k/powerlevel10k.zsh-theme ]] &&
    source $ZSH_PLUGIN_DIR/powerlevel10k/powerlevel10k.zsh-theme
[[ -r $ZSH_PLUGIN_DIR/zsh-autopair/autopair.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-autopair/autopair.zsh
[[ -r $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -r $ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh

# Written by `p10k configure`, per host, so each machine's prompt can differ.
# Loaded after the theme so it can override the theme's defaults, and skipped
# without complaint on a host where the wizard has not been run yet.
[[ -r ${ZDOTDIR:-$HOME}/.p10k.zsh ]] && source "${ZDOTDIR:-$HOME}/.p10k.zsh"

AUTOSUGGESTION_ACCEPT_RIGHT_ARROW=1
