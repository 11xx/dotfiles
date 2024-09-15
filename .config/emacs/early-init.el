;; -*- lexical-binding: t; -*-
(setq package-enable-at-startup nil)

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

(if (is-dark-color-scheme-dbus)
    (progn (set-frame-parameter nil 'alpha-background 10)
           (add-to-list 'default-frame-alist '(alpha-background . 10))
           (add-to-list 'default-frame-alist `(background-color . "#222222"))
           (add-to-list 'default-frame-alist `(foreground-color . "#a6a8a9")))

  (progn (set-frame-parameter nil 'alpha-background 10)
         (add-to-list 'default-frame-alist '(alpha-background . 10))
         (add-to-list 'default-frame-alist `(background-color . "#ffffff"))
         (add-to-list 'default-frame-alist `(foreground-color . "#333333"))))

;; reset transparency
(add-hook 'elpaca-after-init-hook
          (lambda()
            (set-frame-parameter nil 'alpha-background 100)
            (add-to-list 'default-frame-alist '(alpha-background . 100))))
