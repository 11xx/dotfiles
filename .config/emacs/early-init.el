;; -*- lexical-binding: t; -*-

(setq-default lexical-binding t)

(setq user-lisp-directory (locate-user-emacs-file "lisp/"))

(setq package-enable-at-startup t)

(require 'package)
(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(setopt use-package-always-ensure t)

(setq load-prefer-newer t)

(setopt native-comp-async-report-warnings-errors 'silent)

(when (and (fboundp 'startup-redirect-eln-cache) (native-comp-available-p))
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name "var/eln-cache/" user-emacs-directory))))

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
