#!/usr/bin/env sh
theme=neron-light

replace_theme_import() {
    sed -i -E "s|^(import = \[ \"~/.config/alacritty/themes/)(.*)(\.toml.*)|\1$1\3|" \
        "$2"
}

replace_theme_import "${theme}" "${XDG_CONFIG_HOME}"/alacritty/alacritty.toml
