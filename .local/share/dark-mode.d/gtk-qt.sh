#!/usr/bin/env sh
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
gsettings set org.gnome.desktop.interface color-scheme prefer-dark

plasma-apply-colorscheme --platform offscreen KvGnomeDark
