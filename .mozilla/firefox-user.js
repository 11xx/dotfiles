user_pref("ui.key.menuAccessKeyFocuses", false);

user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.av1.enabled", true); // You may skip this if your GPU does not support AV1
user_pref("gfx.x11-egl.force-enabled", true);
user_pref("widget.dmabuf.force-enabled", true);

// enable userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("layout.css.has-selector.enabled", true);
user_pref("browser.tabs.inTitlebar", 0); // with gtk-nocsd, hide titlebar buttons

user_pref("sidebar.animation.enabled", false);
user_pref("sidebar.animation.expand-on-hover.delay-duration-ms", 0); // hover delay
user_pref("sidebar.animation.expand-on-hover.duration-ms", 0); // expand animation
user_pref("sidebar.animation.duration-ms", 0);

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

user_pref("browser.startup.page", 3);  // 3 = Open previous windows and tabs
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);
user_pref("layers.acceleration.disabled", false);

user_pref("app.normandy.api_url", "");
user_pref("app.update.checkInstallTime", false);
user_pref("app.update.disabledForTesting", true);
user_pref("browser.dom.window.dump.enabled", true);
user_pref("browser.newtabpage.activity-stream.asrouter.providers.cfr", "null");
user_pref("browser.newtabpage.activity-stream.asrouter.providers.cfr-fxa", "null");
user_pref("browser.newtabpage.activity-stream.asrouter.providers.message-groups", "null");
user_pref("browser.newtabpage.activity-stream.asrouter.providers.messaging-experiments", "null");
user_pref("browser.newtabpage.activity-stream.asrouter.providers.snippets", "null");
user_pref("browser.newtabpage.activity-stream.asrouter.providers.whats-new-panel", "null");
user_pref("browser.newtabpage.activity-stream.discoverystream.config", "[]");
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("browser.newtabpage.activity-stream.feeds.system.topstories", false);
user_pref("browser.newtabpage.activity-stream.fxaccounts.endpoint", "");
user_pref("browser.newtabpage.activity-stream.tippyTop.service.endpoint", "");
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
// user_pref("browser.startup.page", 0);
user_pref("browser.uitour.enabled", false);
user_pref("browser.warnOnQuit", false);
user_pref("browser.webapps.checkForUpdates", 0);
user_pref("datareporting.healthreport.documentServerURI", "http://%(server)s/dummy/healthreport/");
user_pref("datareporting.healthreport.logging.consoleEnabled", false);
user_pref("datareporting.healthreport.service.enabled", false);
user_pref("datareporting.healthreport.service.firstRun", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("devtools.console.stdout.chrome", true);
user_pref("dom.ipc.reportProcessHangs", false);
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 5);
user_pref("extensions.installDistroAddons", false);
user_pref("extensions.update.enabled", false);
user_pref("extensions.update.notifyUser", false);
// user_pref("focusmanager.testmode", true);
user_pref("general.useragent.updates.enabled", false);
user_pref("geo.provider.testing", true);
user_pref("geo.wifi.scan", false);
user_pref("hangmonitor.timeout", 0);
user_pref("idle.lastDailyNotification", -1);
user_pref("marionette.port", 0);
user_pref("media.gmp-manager.updateEnabled", false);
user_pref("media.sanity-test.disabled", true);
user_pref("network.manage-offline-status", false);
user_pref("network.sntp.pools", "%(server)s");
user_pref("remote.active-protocols", 1);
user_pref("remote.log.level", "Info");
user_pref("security.certerrors.mitm.priming.enabled", false);
user_pref("services.settings.server", "data:,#remote-settings-dummy/v1");
// user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("toolkit.startup.max_resumed_crashes", -1);
