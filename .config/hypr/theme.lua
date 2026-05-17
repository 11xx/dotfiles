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

-- basic
local colorWhite = "rgb(ffffff)"
local colorGrayBg = "rgb(cccccc)"

-- light theme
local colorMonowhiteBg = colorWhite
local colorMonowhiteFg = "rgb(545e62)"
local colorMonowhiteRed = "rgb(ba0d0d)"
local colorMonowhiteCyan = "rgb(006861)"
local colorMonowhitePink = "rgb(b30071)"
local colorMonowhiteGreen = "rgb(1c6b00)"

-- dark theme (neron)
local colorNeronBg = "rgb(222222)"
local colorNeronGreen = "rgb(61bd09)"
local colorNeronCyan = "rgb(16b0cf)"
local colorNeronFg = "rgb(a6a8a9)"
local colorNeronCurrent = "rgb(2f2f2f)"
local colorNeronOrange = "rgb(fd892c)"

-- misc
local colorCurrentIcon = "rgb(666666)"

local lightTheme = {
    colorBg = colorMonowhiteBg,
    colorFg = colorMonowhiteFg,
    colorBgSecondary = "rgb(f6f6f6)",
    hyprbarsColorClose = colorMonowhitePink,
    hyprbarsColorMaximize = colorMonowhiteGreen,
    hyprbarsColorFloat = colorMonowhiteCyan,
    config = {
        decoration = {
            rounding = 4,
        },
        general = {
            gaps_in = 4,
            gaps_out = 8,
            border_size = 3,
            col = {
                active_border = { colors = { colorMonowhitePink }, angle = 45 },
                inactive_border = colorTransparent,
            },
        },
    },
}

local darkTheme = {
    colorBg = colorNeronBg,
    colorFg = colorNeronFg,
    colorBgSecondary = "rgb(27282c)",
    hyprbarsColorClose = colorNeronPink,
    hyprbarsColorMaximize = colorNeronGreen,
    hyprbarsColorFloat = colorNeronCyan,
    config = {
        general = {
            gaps_in = 4,
            gaps_out = 8,
            border_size = 1, -- dark border is easier to see in dark theme
            col = {
                active_border = colorYtOrange,
                inactive_border = colorTransparent,
            },
        },
    },
}

local activeTheme = darkTheme
hl.config(activeTheme.config)

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
