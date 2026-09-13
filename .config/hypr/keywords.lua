hl.config({
    input = {
        kb_layout = "us,br",
        numlock_by_default = true,
        follow_mouse = 1,
        -- Follow Mouse
        -- 0 - disabled
        -- 1 - full
        -- 2 - loose. Will focus mouse on other windows on focus but not the keyboard.
        -- 3 - full loose, will not refocus on click, but allow mouse focus to be
        -- detached from the keyboard like in 2.

        float_switch_override_focus = 0,
        -- See https://wiki.hyprland.org/Configuring/Variables/#:~:text=float_switch_override_focus

        sensitivity = -0.6, -- -1.0 - 1.0, 0 means no modification.

        accel_profile = "flat",
        -- force_no_accel = true -- not recommended in the wiki

        -- keyboard key repeat
        repeat_rate = 80,
        repeat_delay = 200,
    },
})

local kb_options = {
   "fkeys:basic_13-24",
   "caps:none",
}

hl.config({
      input = {
         kb_options = table.concat(kb_options, ","),
      }
})

hl.config({
    general = {
        layout = "dwindle",

        resize_on_border = false,
        extend_border_grab_area = 0,
        resize_corner = 0, -- bottom right
    },
})

hl.config({
    xwayland = {
        use_nearest_neighbor = false, -- necessary when not forcing scaling to make it look ok/blurry
        force_zero_scaling = false, -- makes xwayland sharp when not using
        -- GDK_SCALE, if using scaling is
        -- overriden, but still sharp.
        -- [2023-06-14 Wed 08:24:55 -03]
    },
})

hl.config({
    dwindle = {
        -- See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
        preserve_split = true,
        force_split = 2, -- 0 -> split follows mouse, 1 -> always split to the left (new = left or top) 2 -> always split to the right (new = right or bottom)
        -- use_active_for_splits = true
    },
})

hl.config({
    misc = {
        disable_hyprland_logo = true,

        animate_manual_resizes = true,
        mouse_move_focuses_monitor = true,
        animate_mouse_windowdragging = false,
        enable_swallow = false,
        swallow_regex = "^(Alacritty)$",
        -- swallow_exception_regex = "^(.*Microsoft Edge.*|Mozilla Firefox|.*Chromium|.*Brave.*|wev)$"

        mouse_move_enables_dpms = false,
        key_press_enables_dpms = true,
        -- render_unfocused_fps = 30,
    },
})

hl.config({
    binds = {
        allow_workspace_cycles = true,
        workspace_center_on = 1,
        movefocus_cycles_fullscreen = false,
    },
})
