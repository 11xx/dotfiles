hl.env("__GL_GSYNC_ALLOWED", "1")
hl.env("__GL_VRR_ALLOWED", "1")

hl.config({
    misc = {
        vrr = 2, -- 0 - off, 1 - on, 2 - fullscreen only
    },
    cursor = {
        no_hardware_cursors = 1,
        -- no_break_fs_vrr = true -- not useful for me
    },
})

-- VRR settings are part of hyprland.lua now.
