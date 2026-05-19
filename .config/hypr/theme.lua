-- because Linux is easy

-- Cursor theme names are their directory names
local XCursorTheme = "simp1e-amber-neron"
local hyprcursorTheme = "simp1e-amber-neron"
local XCursorSize = 24
local hyprcursorSize = 24

-- hyprcursor
exec_once("hyprctl setcursor '" .. hyprcursorTheme .. "' " .. hyprcursorSize)
hl.env("HYPRCURSOR_THEME", hyprcursorTheme)
hl.env("HYPRCURSOR_SIZE", tostring(hyprcursorSize))

-- xcursor
exec_once("gsettings set org.gnome.desktop.interface cursor-theme '" .. XCursorTheme .. "'")
exec_once("gsettings set org.gnome.desktop.interface cursor-size " .. XCursorSize)
hl.env("XCURSOR_THEME", XCursorTheme)
hl.env("XCURSOR_SIZE", tostring(XCursorSize))

hl.config({
    cursor = {
        inactive_timeout = 5,
        -- min_refresh_rate = 48,
    },
})

local function theme_conf_file()
    local config_home = os.getenv("XDG_CONFIG_HOME")
    if config_home == nil or config_home == "" then
        config_home = (os.getenv("HOME") or "") .. "/.config"
    end
    return config_home .. "/hypr/themes/active-theme.lua"
end

local function theme_file_for_name(name)
    if name == "light" or name == "dark" then
        return theme_conf_file() .. "." .. name
    end
    return name
end

local function notify_theme_error(message)
    if hl.notification ~= nil then
        hl.notification.create({
            text = message,
            duration = 5000,
            icon = "warning",
            color = colorYtOrange,
        })
    end
end

local function load_theme(name)
    local path = theme_conf_file()
    if name ~= nil then
        path = theme_file_for_name(name)
    end

    local ok, theme = pcall(dofile, path)
    if not ok then
        notify_theme_error("Unable to load Hyprland theme: " .. tostring(path))
        return nil
    end
    if type(theme) ~= "table" then
        notify_theme_error("Hyprland theme did not return a table: " .. tostring(path))
        return nil
    end
    return theme
end

function apply_theme(name)
    local theme = load_theme(name)
    if theme == nil then
        return
    end

    colorBg = theme.colorBg
    colorFg = theme.colorFg
    colorBgSecondary = theme.colorBgSecondary
    hyprbarsColorClose = theme.hyprbarsColorClose
    hyprbarsColorMaximize = theme.hyprbarsColorMaximize
    hyprbarsColorFloat = theme.hyprbarsColorFloat

    hl.config(theme.config)
    if apply_hyprbars_theme ~= nil then
        apply_hyprbars_theme()
    end
end

apply_theme()

hl.config({
    decoration = {
        blur = {
            enabled = true,
            size = 5,
            passes = 3,
            new_optimizations = true,
        },
    },
})

hl.config({
    animations = {
        enabled = false,
    },
})

-- animation=NAME,ONOFF,SPEED,CURVE[,STYLE]
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "default", style = "popin" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "default", style = "fade" })

hl.config({
    decoration = {
        shadow = {
            enabled = false,
            range = 20,
            render_power = 3,
            color = "rgba(00000080)",
            color_inactive = "rgba(00000000)",
            scale = 1,
        },
    },
})
