#!/usr/bin/echo 'This is a source only file.'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

export MANPAGER="bat" # or "less -R --use-color -Dd+r -Du+b"

export LESSOPEN="| /usr/bin/source-highlight-esc.sh %s"
export LESS='-R --use-color -Dd+g$Du+m'

export SYSTEMD_COLORS=256
export TERM='xterm-256color' # TrueColor output
export COLORTERM='truecolor'
