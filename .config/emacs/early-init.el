;; -*- lexical-binding: t; -*-
(setq package-enable-at-startup nil)

(add-hook 'emacs-startup-hook
  (lambda ()
    (message "*** Emacs loaded in %s seconds with %d garbage collections."
             (emacs-init-time "%.2f")
             gcs-done)))

(require 'dbus nil t)
(defun is-dark-color-scheme-dbus ()
  ;; copy of 'auto-dark--is-dark-mode-dbus' from 'auto-dark.el'.
  ;; 0 = light, being a fallback default
  ;; 1 = dark
  ;; 2 = light
   "Read color-scheme from org.freedesktop.portal.Settings appearance interface.
Returns t if dark, nil otherwise."
  (eq 1 (caar (dbus-ignore-errors
                (dbus-call-method
                 :session
                 "org.freedesktop.portal.Desktop"
                 "/org/freedesktop/portal/desktop"
                 "org.freedesktop.portal.Settings" "Read"
                 "org.freedesktop.appearance" "color-scheme")))))

(when (and initial-window-system (is-dark-color-scheme-dbus))
  (setq frame-background-mode 'dark)

  (let ((bg-color "#222222")
        (fg-color "#eeeeee"))
    (add-to-list 'initial-frame-alist `(background-color . ,bg-color))
    (add-to-list 'initial-frame-alist `(foreground-color . ,fg-color))
    (add-to-list 'default-frame-alist `(background-color . ,bg-color))
    (add-to-list 'default-frame-alist `(foreground-color . ,fg-color))))
