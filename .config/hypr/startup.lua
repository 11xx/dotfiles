exec_once("/usr/lib/polkit-kde-authentication-agent-1")

exec_once("lightordark-wallpaper") -- script
exec_once("kdeconnectd") -- KDE connect daemon
exec_once("hypr-dynamic-float-bitwarden-unlock-firefox")
exec_once("sleep 2 && hypr-eww-open")
exec_once("hypr-eww-restart-on-monitor-change")
exec_once("xsettingsd") -- GTK2-3 theme live changes
-- exec_once("gammastep -P")
exec_once("hypridle -c \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf\"")
exec_once("hyprpm reload -n")

hl.env("XDG_MENU_PREFIX", "arch-")
exec_once("kbuildsycoca6 --noincremental")
