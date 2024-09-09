#!/usr/bin/env sh
gsettings set org.gnome.desktop.interface gtk-theme Adwaita
gsettings set org.gnome.desktop.interface color-scheme prefer-light

# icon theme too ?

# `--platform offscreen' is necessary since this script will be run by systemd
plasma-apply-colorscheme --platform offscreen KvGnome
