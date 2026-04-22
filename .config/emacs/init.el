;; -*- lexical-binding: t; -*-
(setopt read-process-output-max (* 3 (* 1024 1024)))

(setopt indent-tabs-mode nil ; disable tabs
        tab-width 2
        tab-stop-list (number-sequence 2 4 2) ; if `tab-width' in not read, use this
        tab-always-indent t)

(setopt fill-column 79)

(setopt inhibit-startup-message t
        initial-scratch-message nil)

(setopt undo-limit (* 1024 1024 1024)
        undo-strong-limit (* 1024 1024 1024)
        undo-outer-limit (* 1024 1024 1024))

(setopt ring-bell-function 'ignore)

(setopt auto-window-vscroll nil)

(setopt delete-by-moving-to-trash t)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(setq gc-cons-threshold (* 500 1024 1024))
(add-hook 'after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

(require 'package)

(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(package-initialize)

(setopt use-package-always-ensure t)

(defvar config-lisp-directory
  (expand-file-name "lisp/" user-emacs-directory)
  "Directory containing local configuration Lisp source files.")

(add-to-list 'load-path config-lisp-directory)

(use-package no-littering
  :config
  (when (fboundp 'startup-redirect-eln-cache)
    (startup-redirect-eln-cache
     (convert-standard-filename
      (expand-file-name "eln-cache" no-littering-var-directory))))

  (add-to-list 'native-comp-eln-load-path
               (convert-standard-filename
                (expand-file-name "eln-cache" no-littering-var-directory))))

(require '11xx-functions)

(defvar 11xx--backup-directory
  (expand-file-name "backups"
                    (expand-file-name "var" user-emacs-directory))
  "Custom backup-files directory.")

;; Auto-save directory variable
(defvar 11xx--auto-save-directory
  (expand-file-name "auto-save"
                    (expand-file-name "var" user-emacs-directory))
  "Custom auto-save files directory.")

(ensure-directory 11xx--backup-directory)
(ensure-directory 11xx--auto-save-directory)

(setopt backup-directory-alist `((".*" . ,11xx--backup-directory))
        auto-save-file-name-transforms `(("\\(?:[^/]*/\\)*\\(.*\\)" ,(concat 11xx--auto-save-directory "\\\\1") t))
        auto-save-list-file-prefix 11xx--auto-save-directory
        auto-save-list-file-name (concat 11xx--auto-save-directory "/auto-save-list")
        make-backup-files t    ; backup of a file the first time it is saved.
        backup-by-copying t    ; don't clobber symlinks
        version-control t      ; version numbers for backup files
        delete-old-versions t  ; delete excess backup files silently
        kept-old-versions 6    ; oldest versions to keep when a new numbered backup is made (default: 2)
        kept-new-versions 9    ; newest versions to keep when a new numbered backup is made (default: 2)
        auto-save-default t    ; auto-save every buffer that visits a file
        auto-save-timeout 10   ; number of seconds idle time before auto-save (default: 30)
        auto-save-interval 150) ; number of keystrokes between auto-saves (default: 300)

;; silence "Auto-saving..." messages on minibuffer
(advice-add 'do-auto-save :around
  (lambda (orig-fn &rest args)
    (let ((inhibit-message t))
      (apply orig-fn args))))

(setopt create-lockfiles nil)

(defun loaddefs-setup (&optional lisp-dir)
  "Generate and load autoloads for Lisp files in LISP-DIR.

Scans LISP-DIR (defaults to `config-lisp-directory') for autoload
cookies and writes the result to config-loaddefs.el in
`no-littering-var-directory', adding LISP-DIR to `load-path'."
  (let* ((dir (file-truename (or lisp-dir config-lisp-directory)))
         (out (expand-file-name "config-loaddefs.el" no-littering-var-directory)))
    (loaddefs-generate dir out)
    (load out nil :nomessage)))

(loaddefs-setup config-lisp-directory)

(require '11xx-functions)
(require 'utf-8-default)
(require '11xx-defaults)
(require '11xx-completion)
(require '11xx-ui)
(require '11xx-navigation)
(require '11xx-half-scroll)
(require '11xx-pixel-scroll)

(require '11xx-dired)

(require '11xx-magit)
(with-eval-after-load 'org
  (require '11xx-org))

(require '11xx-modes)
(require 'llm-ai-assistants)
(require '11xx-pdf-viewer)
