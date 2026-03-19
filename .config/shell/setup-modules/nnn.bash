#!/usr/bin/echo 'This is a source only file.'
append_nnn_plug_commands() {
    # local mode="$1"  # 'append' or 'replace'
    local items="$1"

    # if [[ "$mode" == "append" ]]; then
    NNN_PLUG_COMMANDS="${NNN_PLUG_COMMANDS:+$NNN_PLUG_COMMANDS;}$items"
    # elif [[ "$mode" == "replace" ]]; then
    #     # #todo replace using string matching?
    #     NNN_PLUG_COMMANDS="$items"
    # else
    #     echo "Invalid mode. Please specify 'append' or 'replace'."
    #     return 1
    # fi
}


append_nnn_plug_official() {
    local items="$1"

    NNN_PLUG_OFFICIAL="${NNN_PLUG_OFFICIAL:+$NNN_PLUG_OFFICIAL;}$items"
}

alias anpca='append_nnn_plug_commands'
alias anpoa='append_nnn_plug_official'

anpca '0:!sacdx "$nnn"'
anpca 'm:!mediainfo-color "$nnn"'
# anpca 'q:!clear && audio-quality "$nnn"'
# anpca 'E:!echo-files "$nnn"'
anpca 'o:launch4nnn'
anpca 'x:xtodir-nnn'
anpca 's:dusum4nnn'
# anpca 'a:!archive "$nnn"'
# anpca 'c:!archive -11 "$nnn"'
# anpca 'r:rclone-gcrypt-to-local4nnn'

anpoa 'd:dragdrop'
anpoa 'F:fzopen'
anpoa 'i:imgview'
anpoa 'p:preview-tui'
anpoa 'z:autojump' # using with zoxide

## nnn = https://github.com/jarun/nnn/wiki/Usage#configuration
NNN_PLUG="$NNN_PLUG_COMMANDS;$NNN_PLUG_OFFICIAL"
export NNN_PLUG
export NNN_TRASH=1

# BLK="04" CHR="04" DIR="04" EXE="00" REG="00" HARDLINK="00" SYMLINK="06" MISSING="00" ORPHAN="01" FIFO="0F" SOCK="0F" OTHER="02"
# export NNN_FCOLORS="0404040404040404"

# export NNN_COLORS="2136" # colors of the 4 "workspaces"
# export NNN_TMPFILE=${XDG_STATE_HOME:-$HOME/.local/state}/nnn/lastd
# [[ ! -d ${NNN_TMPFILE%lastd} ]] && mkdir -p "${NNN_TMPFILE%.lastd}"
# export NNN_SEL=${XDG_STATE_HOME:-$HOME/.local/state}/nnn/selection
export NNN_TMPFILE=/tmp/nnn.tmp
export NNN_FIFO=/tmp/nnn.fifo
export NNN_SEL=/tmp/nnn.sel
#export NO_COLOR=1
#NNN_FCOLORS='c1e2272e006033f7c6d6abc4'
export NNN_OPENER="$OPENER"
export NNN_FALLBACK_OPENER="$OPENER"
# Hidden files on top
export LC_COLLATE="C"

# used by plugins
export NNN_PREVIEWIMGPROG=chafa
export NNN_PAGER=$PAGER
export NNN_TERMINAL=$TERMINAL


# include hidden files on 'r'ename
# [[https://github.com/jarun/nnn/commit/49be2cfcd19e800f69f2aa4e371db2bb13fc6a7c][Fix #1153: sync hidden on batch rename · jarun/nnn@49be2cf]]
export INCLUDE_HIDDEN=1
n() {
    VISUAL=$EDITOR # nnn reads in order: $VISUAL -> $EDITOR -> vi

    # Block nesting of nnn in subshells
    [ "${NNNLVL:-0}" = 0 ] || {
        echo "nnn is already running"
        return
    }

    # The default behaviour is to cd on quit (nnn checks if NNN_TMPFILE is set)
    # To cd on quit only on ^G, remove the "export" as in:
    #     NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    # export NNN_TMPFILE="${XDG_STATE_HOME:-$HOME/.local/state}/nnn/.lastd"

    # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
    # stty start undef
    # stty stop undef
    # stty lwrap undef
    # stty lnext undef

    # set color scheme
    # nnn_dark_light_set # defined in sourced `nnn-setup.bash'
    # ^ disabled because using 'proper' ansi color theme.

    if command -v cpg >/dev/null && command -v mvg >/dev/null; then
        nnn -EHd -r "$@"
    else
        nnn -EHd "$@"
    fi

    if [ -f "$NNN_TMPFILE" ]; then
        . "$NNN_TMPFILE"
        rm -f "$NNN_TMPFILE" > /dev/null
    fi
}

nnn_cd()
{
    if ! [ -z "$NNN_PIPE" ]; then
        printf "%s\0" "0c${PWD}" > "${NNN_PIPE}" !&
    fi
}

trap nnn_cd EXIT

block=08
char=03
dir=04
exe=02
regular=00
hardlink=05
symlink=06
miss=07 # also affects details
orph=09
fifo=0d
socket=05
unkn=01

export NNN_FCOLORS="$block$char$dir$exe$regular$hardlink$symlink$miss$orph$fifo$socket$unkn"

unset block char dir exe regular hardlink symlink miss orph fifo socket unkn
