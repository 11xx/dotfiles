if [[ $TERM == "dumb" ]] || [[ -n $INSIDE_EMACS ]]; then
    # NOTE: set this on BOTH `.zshrc' AND `.zshenv'
    unsetopt zle
    PS1='$ '
    export HISTFILE=$HOME/.tramp_history
    return
fi

[[ -n $DEBUG ]] && set -x

[[ $- != *i* ]] && return

for _fragment in "${ZDOTDIR}"/rc.d/*.zsh(N.); do
    source "$_fragment"
done
unset _fragment

source "$XDG_CONFIG_HOME/shell/aliases"

#bindkey '^I'   complete-word       # tab          | complete
bindkey '^[[Z'  forward-word  # shift + tab  | autosuggest
# ctrl-left and ctrl-right
bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word
# ctrl-bs and ctrl-del
bindkey "\e[3;5~" kill-word
bindkey "\C-_"    backward-kill-word
# del, home and end
bindkey "\e[3~" delete-char
bindkey "\e[H"  beginning-of-line
bindkey "\e[F"  end-of-line
# alt-bs
bindkey "\e\d"  undo
# ctrl+e
bindkey "^E"    end-of-line
bindkey "^F"    autosuggest-fetch

bindkey -e '' undo
bindkey -e 'd' kill-word

# search
# bindkey '' up-line-or-search
# bindkey '' down-line-or-search

bindkey "^S" history-incremental-search-backward
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# https://stackoverflow.com/questions/26409337/inserting-a-newline-in-a-multiline-zsh-command-pulled-from-history/26461450#26461450
# bindkey '^M'   accept-line # vterm fix
bindkey '^[^M' self-insert-unmeta # Insert newline without accepting the command

# `'^J' as self-insert-unmeta' conflicts with Emacs vterm, so only set
# it outside.
if [[ ! $INSIDE_EMACS == vterm ]] || [[ -z $EMACS_VTERM_PATH ]]; then
    bindkey '^J' self-insert-unmeta
fi

bindkey '^H'   backward-kill-word
bindkey '^F'   forward-char

if [[ -n ${WAYLAND_DISPLAY-} ]] && (( $+commands[wl-copy] && $+commands[wl-paste] )); then
    xw-copy-region-as-kill() {
        zle copy-region-as-kill
        print -rn -- "$CUTBUFFER" | wl-copy --type text/plain;charset=utf-8
    }
    zle -N xw-copy-region-as-kill

    xw-kill-region() {
        zle kill-region
        print -rn -- "$CUTBUFFER" | wl-copy --type text/plain;charset=utf-8
    }
    zle -N xw-kill-region

    xw-kill-line() {
        zle kill-line
        print -rn -- "$CUTBUFFER" | wl-copy --type text/plain;charset=utf-8
    }
    zle -N xw-kill-line

    xw-yank() {
        CUTBUFFER=$(wl-paste --no-newline 2>/dev/null) || return
        zle yank
    }
    zle -N xw-yank

    bindkey -e '^[w' xw-copy-region-as-kill
    bindkey -e '^W'  xw-kill-region
    bindkey -e '^Y'  xw-yank
    bindkey -e '^K'  xw-kill-line
else
    bindkey -e '^[w' copy-region-as-kill
    bindkey -e '^W'  kill-region
    bindkey -e '^Y'  yank
    bindkey -e '^K'  kill-line
fi

bindkey -r '^[x' # execute-named-cmd

# remap default ctrl + c (interrupt)
stty intr '^G' <$TTY >$TTY

set -o ignoreeof

[[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]] &&
    stty -ixon <$TTY >$TTY

# Disable lack-of-newline percentile symbol https://unix.stackexchange.com/questions/167582/why-zsh-ends-a-line-with-a-highlighted-percent-symbol/167600#167600
unsetopt PROMPT_SP
# https://www.cassey.dev/til/2020-11-09-zsh-percent-signs/
# https://unix.stackexchange.com/questions/167582/why-zsh-ends-a-line-with-a-highlighted-percent-symbol
# export PROMPT_EOL_MARK=''

function is_command() {
    command -v "$1" &> /dev/null && return 0
    return 1
}

localFPATH="${XDG_DATA_HOME}"/zsh/functions
mkdir -p "$localFPATH"
fpath+="$localFPATH"

function is_user_fpath_file() {
    if [[ -f ${localFPATH%/}/$1 ]]; then
        return 0
    else
        return 1
    fi
}

function download_to_user_fpath() {
    if is_user_fpath_file "$1"; then
        return 0
    else
        printf 'Downloading "%s" to "%s"\nSource: %s\n\n' "$1" "$localFPATH"/"$1" "$2"
        curl -sL -o "$localFPATH"/"$1" "$2"
    fi
}

download_to_user_fpath delsel-mode 'https://raw.githubusercontent.com/knu/zsh-delsel-mode/master/delsel-mode'
# then autoload it
autoload -Uz delsel-mode
delsel-mode

autoload -U +X bashcompinit && bashcompinit

is_command stack && {
    is_user_fpath_file "$1" ||
        stack --bash-completion-script `which stack` > "$localFPATH"/_stack
}

# The following lines were added (generated) by compinstall
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' matcher-list '+' 'l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:]}={[:upper:]} r:|[._-]=** r:|=**'
zstyle ':completion:*' menu select=0
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle :compinstall filename "$ZDOTDIR/.zshrc"

# autoload -Uz compinit && compinit
_comp_options+=(globdots) # Include hidden files.
# End of lines added by compinstall

shellCompletionDir=${XDG_DATA_HOME}/shell-completion
[[ -d ${shellCompletionDir}/zsh ]] && fpath+=${shellCompletionDir}/zsh

autoload -Uz compinit && compinit

[[ -d ${shellCompletionDir}/bash ]] &&
    for file in $(find "${shellCompletionDir}"/bash/* -type f); do
        [[ -f ${file} ]] && source "${file}"
    done

setopt histignorealldups

source "$XDG_CONFIG_HOME"/shell/setup-modules-source.sh
