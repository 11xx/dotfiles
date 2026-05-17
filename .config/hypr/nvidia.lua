hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

hl.env("GBM_BACKEND", "nvidia-drm")

hl.config({
    cursor = {
        no_hardware_cursors = 1,
    },
})

-- https://wiki.hyprland.org/Nvidia/#va-api-hardware-video-acceleration
hl.env("NVD_BACKEND", "direct")

-- Nvidia settings are part of hyprland.lua now.
