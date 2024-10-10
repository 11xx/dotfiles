;; -*- lexical-binding: t; -*-
(setq package-enable-at-startup nil)

(add-hook 'emacs-startup-hook
  (lambda ()
    (message "*** Emacs loaded in %s seconds with %d garbage collections."
             (emacs-init-time "%.2f")
             gcs-done)))

(setopt org-fold-core-style 'text-properties)
