hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Firefox
hl.env("EGL_PLATFORM", "wayland") -- unset this when on X11
hl.env("MOZ_ENABLE_WAYLAND", "1") -- necessary otherwise Firefox will only try X11

hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")

exec_once("dbus-update-activation-environment --systemd --all")
exec_once("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE")
exec_once("systemctl --user import-environment GDK_BACKEND QT_QPA_PLATFORM QT_AUTO_SCREEN_SCALE_FACTOR QT_WAYLAND_DISABLE_WINDOWDECORATION SDL_VIDEODRIVER CLUTTER_BACKEND")
exec_once("systemctl --user import-environment EGL_PLATFORM MOZ_ENABLE_WAYLAND")
exec_once("systemctl --user import-environment XDG_MENU_PREFIX")
