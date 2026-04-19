#!/usr/bin/env sh
alacrittyDir="${XDG_CONFIG_HOME}"/alacritty

alacritty_link_theme() {
    (
        cd "${alacrittyDir}"/themes
        ln -sf "${themeFile}" current-theme.toml
    )
}

themeFile=neron-dark.toml

alacritty_link_theme
