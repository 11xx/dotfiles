#!/usr/bin/env sh
# [[file:../../../.config/darkman/README.org::*Alacritty][Alacritty:1]]
theme=neron-light

replace_theme_import() {
    sed -i -E "s|^(import = \[ \"~/.config/alacritty/themes/)(.*)(\.toml.*)|\1$1\3|" \
        "$2"
}

replace_theme_import "${theme}" "${XDG_CONFIG_HOME}"/alacritty/alacritty.toml
# Alacritty:1 ends here

# [[file:../../../.config/darkman/README.org::darkman-alacritty-colors-replace][darkman-alacritty-colors-replace]]
replace_theme_import() {
    sed -i -E "s|^(import = \[ \"~/.config/alacritty/themes/)(.*)(\.toml.*)|\1$1\3|" \
        "$2"
}

replace_theme_import "${theme}" "${XDG_CONFIG_HOME}"/alacritty/alacritty.toml
# darkman-alacritty-colors-replace ends here
