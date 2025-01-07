if [ "$(tty)" = "/dev/tty1" ] # check if it is the first tty login
then
    # echo 'Autostart of window manager disabled.'
    pgrep '^'"$WM"'$' && printf '"%s" is already running. Skipping its startup...\n' "$WM" && return
    exec "$WM"
    # sx
fi
