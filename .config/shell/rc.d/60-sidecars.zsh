# Managed by Ansible (role: shell) — edit the role, not this file.
#
# Each sidecar is probed before it is initialised, so a host that carries only
# some of them still gets a working shell instead of an error on every login.

# --disable-up-arrow keeps Up bound to zsh's own prefix search from
# 50-keybinds.zsh; atuin stays on Ctrl-R.
(( $+commands[atuin] )) && eval "$(atuin init zsh --disable-up-arrow)"

# --cmd cd shadows cd entirely, so plain `cd` learns frecency and no second verb
# has to be remembered.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"
