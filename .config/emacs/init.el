;; -*- lexical-binding: t; -*-
(setq-default lexical-binding t)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

;; (setopt use-package-always-ensure t)

(add-to-list 'load-path (expand-file-name "11xx" user-emacs-directory))
;; (add-to-list 'load-path (expand-file-name "elisp" user-emacs-directory))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))

(add-to-list 'native-comp-eln-load-path
             (expand-file-name "var/eln-cache/" user-emacs-directory))

(use-package no-littering
  :ensure t)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(use-package 11xx-setup)
(use-package 11xx-defaults)

(use-package 11xx-completion)

(use-package 11xx-ui
  :after frame)
;; (setup 11xx-ui
;;   (:load-after frame))

(use-package 11xx-navigation)
(use-package 11xx-half-scroll
  :after frame)
(use-package 11xx-pixel-scroll
  :after frame)

(use-package 11xx-dired
  :after dired)

(use-package 11xx-magit
  :after dired)

(use-package 11xx-gc)
(use-package 11xx-org)
(use-package 11xx-modes)

(add-hook 'emacs-startup-hook
  (lambda ()
    (message "*** Emacs loaded in %s seconds with %d garbage collections."
             (emacs-init-time "%.2f")
             gcs-done)))
