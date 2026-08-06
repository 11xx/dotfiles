# Managed by Ansible (role: shell) — edit the role, not this file.

autoload -U colors && colors

setopt autocd extendedglob nomatch notify
unsetopt beep

# Zsh marks a command whose output lacked a trailing newline with an inverted
# percent sign. It corrupts copied output far more often than it informs.
unsetopt PROMPT_SP

# Ctrl-D on an empty line closes the shell, which over SSH tends to mean losing
# a session to a stray keystroke. Require an explicit exit instead.
set -o ignoreeof
