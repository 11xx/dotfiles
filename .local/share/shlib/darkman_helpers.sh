check_file() {
    [ -f "$1" ] && return 0
    printf 'The file "%s" does not exist, aborting...\n' "$1"
    exit 1
}

check_cmd() {
    ! command -v "$1" > /dev/null && exit 1
}

running_check() {
    pgrep -ixU "$(id -u)" "$1" > /dev/null
}

running_check_killall() {
    running_check "$1" && killall "$1" --quiet
}

set_ini_key() {
    local file="$1" section="$2" key="$3" value="$4"
    awk -v sec="[$section]" -v k="$key" -v v="$value" '
        BEGIN { OFS="="; in_sec=0; done=0 }
        /^\[/ {
            if ($0 == sec) { in_sec=1; print; print k, v; done=1; next }
            in_sec=0
        }
        in_sec && $0 ~ "^" k "=" { next }
        { print }
        END { if (!done) { print ""; print sec; print k, v } }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}
