# Managed by Ansible (role: shell) — edit the role, not this file.
#
# Base Emacs bindings for ak's terminal. Host-specific bindings in .zshrc
# take precedence.

bindkey -e

# Word motion and deletion.
bindkey '^[[1;5D' backward-word          # ctrl-left
bindkey '^[[1;5C' forward-word           # ctrl-right
bindkey '^[[3;5~' kill-word              # ctrl-delete
bindkey '^H'      backward-kill-word     # ctrl-backspace
bindkey '^[[Z'    forward-word           # shift-tab, accepts a suggestion word

# Keys whose escape sequences zsh leaves unbound.
bindkey '^[[3~' delete-char
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[^?'  undo                     # alt-backspace

# Up/Down search history for the prefix already typed, rather than walking every
# entry. Atuin takes ctrl-R and deliberately leaves these alone.
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# Reaching ctrl-S requires software flow control off, or the terminal freezes
# instead of searching. Guarded because a shell without a tty has no stty to run.
if [[ -r ${TTY:-} && -w ${TTY:-} ]] && (( $+commands[stty] )); then
    stty -ixon <$TTY >$TTY
fi
bindkey '^S' history-incremental-search-backward

# Insert a literal newline instead of running the line. Emacs' vterm sends the
# same byte for accept-line, so it keeps zsh's default there.
if [[ $INSIDE_EMACS != vterm ]] || [[ -z $EMACS_VTERM_PATH ]]; then
    bindkey '^J' self-insert-unmeta
fi
bindkey '^[^M' self-insert-unmeta        # alt-enter

bindkey -r '^[x'                         # execute-named-cmd, only ever a typo
