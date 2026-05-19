local hyprbars_buttons_registered = false

local function hyprbars_loaded()
    return hl.plugin ~= nil and hl.plugin.hyprbars ~= nil
end

local function notify_hyprbars_missing()
    if hl.notification ~= nil then
        hl.notification.create({
            text = "Hyprbars plugin is not loaded; run hyprpm enable hyprbars && hyprpm reload",
            duration = 5000,
            icon = "warning",
            color = colorYtOrange,
        })
    end
end

function apply_hyprbars_theme()
    if not hyprbars_loaded() then
        return
    end

    hl.config({
        plugin = {
            hyprbars = {
                bar_height = 20,
                bar_color = colorBgSecondary,
                col = {
                    text = colorFg,
                },
                bar_text_size = 9,
                bar_text_font = "Noto Sans",
                bar_button_padding = 10,
                bar_padding = 5,
                bar_precedence_over_border = true,
            },
        },
    })
end

local function add_hyprbars_buttons()
    if not hyprbars_loaded() or hyprbars_buttons_registered then
        return
    end

    hl.plugin.hyprbars.add_button({
        bg_color = hyprbarsColorClose,
        fg_color = colorFg,
        size = 16,
        icon = "",
        action = "hyprctl dispatch killactive",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = hyprbarsColorMaximize,
        fg_color = colorFg,
        size = 16,
        icon = "",
        action = "hyprctl dispatch fullscreen 2",
    })
    hl.plugin.hyprbars.add_button({
        bg_color = hyprbarsColorFloat,
        fg_color = colorFg,
        size = 16,
        icon = "",
        action = "hyprctl dispatch togglefloating",
    })

    hyprbars_buttons_registered = true
end

local function setup_hyprbars(notify_missing)
    if not hyprbars_loaded() then
        if notify_missing then
            notify_hyprbars_missing()
        end
        return
    end

    apply_hyprbars_theme()
    add_hyprbars_buttons()
end

setup_hyprbars(false)
hl.on("hyprland.start", function()
    hl.timer(function()
        setup_hyprbars(true)
    end, { timeout = 2000, type = "oneshot" })
end)

if hyprbars_loaded() then
    window_rule({ float = false }, { ["hyprbars:no_bar"] = true })
end
