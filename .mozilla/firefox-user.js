user_pref("ui.key.menuAccessKeyFocuses", false);

user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.av1.enabled", true); // You may skip this if your GPU does not support AV1
user_pref("gfx.x11-egl.force-enabled", true);
user_pref("widget.dmabuf.force-enabled", true);

// enable userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("layout.css.has-selector.enabled", true);

user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("widget.use-xdg-desktop-portal.location", 1);
user_pref("widget.use-xdg-desktop-portal.mime-handler", 1);
user_pref("widget.use-xdg-desktop-portal.open-uri", 1);
user_pref("widget.use-xdg-desktop-portal.settings", 1);

user_pref("gfx.webrender.all", true);
user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);
// setting all the following dom.ipc to higher values made a noticeable difference
user_pref("dom.ipc.processCount", 8); // was 8 by default
user_pref("dom.ipc.processCount.extension", 1); // default is 1 and CANNOT be changed otherwise it will disable extensions.
user_pref("dom.ipc.processCount.file", 8); // was 1
user_pref("dom.ipc.processCount.privilegedabout", 8); // was 1
user_pref("dom.ipc.processCount.privilegedmozilla", 8); // was 1
user_pref("dom.ipc.processCount.webIsolated", 8); // was 4

// store cache in xdg_runtime_dir's tmpfs
user_pref("browser.cache.disk.parent_directory", "/run/user/1000/firefox"); // update UID if it's not 1000
user_pref("browser.sessionstore.interval", 60000); // in milliseconds
