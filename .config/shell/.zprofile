if [ "$(tty)" = "/dev/tty1" ] # check if it is the first tty login
then
    WM_LOCKFILE=${XDG_RUNTIME_DIR:-/tmp}/wmstart.lock

    [[ -f $WM_LOCKFILE ]] &&
        printf '"%s" lockfile present, skipping WM "%s" restart...\n' "$WM_LOCKFILE" "$WM" >&2 &&
        return

    pgrep '^'"$WM"'$' &&
        printf '"%s" is already running. Skipping its startup...\n' "$WM" &&
        return

    touch "${WM_LOCKFILE}"

    exec "$WM"
fi
