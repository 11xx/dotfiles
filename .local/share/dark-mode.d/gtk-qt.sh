#!/usr/bin/env sh
source "${XDG_DATA_HOME}"/shlib/darkman_helpers.sh

gsettings_plasma() {
    if ! printf '%s' "$1" | grep -qEi 'light|dark'; then
        printf 'Error: gsettings_plasma argument must be "dark" or "light"' >&2
        return 1
    fi

    gsettings set org.gnome.desktop.interface color-scheme prefer-"${1}"
    gsettings set org.gnome.desktop.interface gtk-theme "${gtkTheme}"
    plasma-apply-colorscheme --platform offscreen "${qtTheme}"
}

qtct() {
    qt6conf=~/.config/qt6ct/qt6ct.conf
    qt5conf=~/.config/qt5ct/qt5ct.conf
    set_ini_key "${qt6conf}" Appearance icon_theme "${iconTheme}"
    set_ini_key "${qt6conf}" Appearance style "${gtkTheme}"
    set_ini_key "${qt5conf}" Appearance icon_theme "${iconTheme}"
    set_ini_key "${qt5conf}" Appearance style "${gtkTheme}"
}

gtkTheme=Adwaita-dark
qtTheme=KvGnomeDark
iconTheme=Papirus-Dark

qtct
gsettings_plasma dark
