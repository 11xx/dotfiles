if [ "$(tty)" = "/dev/tty1" ] # check if it is the first tty login
then
    if uwsm check may-start; then
        exec uwsm start -- hyprland
    fi
fi
