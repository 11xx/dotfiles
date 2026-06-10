-- Polkit dialogs
window_rule({ class = "^(org.kde.polkit-kde-authentication-agent-1)$" }, { float = true })

-- Picture-in-Picture (dynamic title, requires full regex match)
window_rule({ title = "^(Picture-in-Picture)$" }, { float = true, pin = true })

-- Emacs floating frames
window_rule({ title = "^(Edit with Emacs FRAME)$" }, { float = true })

-- Wine/Proton windows
window_rule({ class = "^.*(floatWMRULE|FLOAT_WMRULE)$" }, { float = true })
window_rule({ title = "^.*(floatWMRULE|FLOAT_WMRULE)$" }, { float = true })

-- File open dialogs (anchor pattern at start, not middle)
window_rule({ title = "^Open File" }, { float = true })
window_rule({ title = "^Vivaldi Settings:" }, { float = true })

-- MPV suppress maximize (prevents maximization requests)
window_rule({ class = "^mpv$" }, { suppress_event = "maximize" })

-- Floating .exe windows (Windows app shortcuts)
window_rule({ class = ".*\\.exe$" }, { float = true })

-- Emacs
window_rule({ class = "emacs", title = "Ediff" }, {
    float = true,
    size = { 720, 330 },
    move = { "cursor_x-(window_w*0.5)", "cursor_y-(window_h*0.5)" },
})

-- Blender
window_rule({ title = "^Blender (Render|Preferences)$" }, { float = true })

-- Steam & Games
window_rule({ title = "^Create or select new Steam library folder$" }, { float = true })
window_rule({ class = "steam", title = "Friends List" }, { float = true })
window_rule({ class = "steam", title = "Steam Settings" }, { float = true })
-- window_rule({ class = "steam" }, { float = true }) -- Uncomment to float all Steam windows
-- Steam apps: send to workspace 6, render in background for FPS stability
window_rule({ class = "^(steam_app_[0-9]+)$" }, { monitor = "0 silent", workspace = "6 silent" })
-- windows_rule({ class = "steam", title "notificationtoasts.*" }) -- Steam buttom right popups

-- Elden Ring: prevent FPS drops when unfocused
window_rule({ class = "steam_app_2622380", title = "ELDEN RING NIGHTREIGN" }, { render_unfocused = true })

-- File Managers
window_rule({ class = "org.kde.ark", title = "^(File Already Exists).*Ark$" }, { float = true })
window_rule({ class = "org.kde.dolphin", title = "^(Choose Application).*Dolphin$" }, { float = true })

local filePickerSize = { 1500, 900 }
window_rule({ class = "org.freedesktop.impl.portal.desktop.kde" }, { float = true, size = filePickerSize })
window_rule({ class = "^xdg-desktop-portal-gtk$", title = "^File Upload.*$" }, { float = true, size = filePickerSize })
window_rule({ class = "^xdg-desktop-portal-gtk$", title = "^Open Folder$" }, { float = true, size = filePickerSize })
window_rule({ class = "pcmanfm-qt", title = "Removable medium is inserted" }, { float = true, size = filePickerSize })

-- Firefox
-- Empty title notifications (popups with no text)
window_rule({ class = "firefox", title = "^$" }, { float = true })
window_rule({ class = "firefox", title = "Library" }, { float = true })

-- Global rule: disable blur for windows with empty class/title (xwayland context menus)
window_rule({ class = "^()$", title = "^()$" }, { no_blur = true })

-- Inkscape
window_rule({ class = "org.inkscape.Inkscape", title = "^(SVG Input)$" }, { float = true })

window_rule({ initial_class = "^(dragon-drop)$" }, { float = true, pin = true })

window_rule({ class = ".*" }, { suppress_event = "maximize" })

window_rule({ float = true }, { border_color = colorNeronPink })
