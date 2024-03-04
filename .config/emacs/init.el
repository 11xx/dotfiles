;; -*- lexical-binding: t; -*-
(setq-default lexical-binding t)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)
(unless package-archive-contents
  (package-refresh-contents))

(add-to-list 'load-path (expand-file-name "11xx" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require '11xx-functions (expand-file-name "11xx/11xx-functions.el" user-emacs-directory))

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))

(add-to-list 'native-comp-eln-load-path
             (expand-file-name "var/eln-cache/" user-emacs-directory))

(use-package no-littering
  :ensure t)

;; **** Backup directory variable
(defvar v/backup-directory
  (expand-file-name "backups" no-littering-var-directory)
  "Custom backup-files directory.")
(f/check-make-directory v/backup-directory)

;; Auto-save directory variable
(defvar v/auto-save-directory
  (expand-file-name "auto-save" no-littering-var-directory)
  "Custom auto-save files directory.")
(f/check-make-directory v/auto-save-directory)

;; ;; add random number to auto save file list
;; (defun f/auto-save-list-file-name-function ()
;;   (let ((basename (concat v/auto-save-directory "/auto-save-list-"))
;;         (random-number (number-to-string (random))))
;;     (concat basename (substring random-number 0 8) "~")))
;; (setq auto-save-list-file-name-function #'f/auto-save-list-file-name-function)

(setopt backup-directory-alist `((".*" . ,v/backup-directory))
        auto-save-file-name-transforms `(("\\(?:[^/]*/\\)*\\(.*\\)" ,(concat v/auto-save-directory "\\\\1") t))
        auto-save-list-file-prefix v/auto-save-directory
        auto-save-list-file-name (concat v/auto-save-directory "/auto-save-list")
        make-backup-files t    ; backup of a file the first time it is saved.
        backup-by-copying t    ; don't clobber symlinks
        version-control t      ; version numbers for backup files
        delete-old-versions t  ; delete excess backup files silently
        kept-old-versions 6    ; oldest versions to keep when a new numbered backup is made (default: 2)
        kept-new-versions 9    ; newest versions to keep when a new numbered backup is made (default: 2)
        auto-save-default t    ; auto-save every buffer that visits a file
        auto-save-timeout 1   ; number of seconds idle time before auto-save (default: 30)
        auto-save-interval 200) ; number of keystrokes between auto-saves (default: 300)

(setopt create-lockfiles nil)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(use-package 11xx-setup)
(use-package 11xx-defaults)
(use-package 11xx-completion)

(use-package 11xx-ui
  :after frame)

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
