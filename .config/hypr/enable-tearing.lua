hl.config({
    general = {
        allow_tearing = true,
    },
})

hl.env("WLR_DRM_NO_ATOMIC", "1")

window_rule({ class = "^eldenring.exe$" }, { immediate = true })
window_rule({ class = "^gamescope$" }, { immediate = true })
window_rule({ class = "^steam_app_[0-9]+$" }, { immediate = true })
window_rule({ class = "^mpv$" }, { immediate = true })
window_rule({ class = "love", title = "Freesync test" }, { immediate = true })

-- Tearing settings are part of hyprland.lua now.
