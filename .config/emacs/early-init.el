;; -*- lexical-binding: t; -*-
(setq package-enable-at-startup nil)

(add-hook 'emacs-startup-hook
  (lambda ()
    (message "*** Emacs loaded in %s seconds with %d garbage collections."
             (emacs-init-time "%.2f")
             gcs-done)))

(setopt org-fold-core-style 'text-properties)

(require 'dbus nil t)
(defun is-dark-color-scheme-dbus ()
  ;; copy of 'auto-dark--is-dark-mode-dbus' from 'auto-dark.el'.
  "Read color-scheme from org.freedesktop.portal.Settings appearance interface."
  (eq 1 (caar (dbus-ignore-errors
                (dbus-call-method
                 :session
                 "org.freedesktop.portal.Desktop"
                 "/org/freedesktop/portal/desktop"
                 "org.freedesktop.portal.Settings" "Read"
                 "org.freedesktop.appearance" "color-scheme")))))

;; (set-face-attribute 'default nil :foreground 'unspecified)
;; (set-face-attribute 'default nil :background 'unspecified)

;; the most useless nitpick
(defun f/early-init--set-faces (fg bg alpha)
  (set-frame-parameter nil 'alpha-background alpha)
  (add-to-list 'initial-frame-alist `(alpha-background . ,alpha))
  (add-to-list 'initial-frame-alist `(background-color . ,bg))
  (add-to-list 'initial-frame-alist `(foreground-color . ,fg)))

(if (is-dark-color-scheme-dbus)
    (f/early-init--set-faces "#333333" "#ffffff" 10)
  (f/early-init--set-faces "#eeeeee" "#222222" 10))

;; reset faces
(add-hook 'elpaca-after-init-hook
          (lambda() (set-face-attribute 'default nil :foreground 'unspecified)
            (set-face-attribute 'default nil :background 'unspecified)
            (set-frame-parameter nil 'alpha-background nil)))
