if [ "$(tty)" = "/dev/tty1" ] # check if it is the first tty login
then
    echo 'Autostart of window manager disabled.'
    # pgrep "$WM" || "$WM"
    # sx
fi
