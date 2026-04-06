;; -*- lexical-binding: t; -*-
(defvar config-lisp-directory
  (expand-file-name "lisp/" user-emacs-directory)
  "Directory containing local configuration Lisp source files.")

(add-to-list 'load-path config-lisp-directory)

(require 'elpaca-bootstrap)

(require '11xx-setup)

(require 'init-no-littering)
(require 'init-backup-auto-save)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(setq gc-cons-threshold (* 500 1024 1024))
(add-hook 'elpaca-after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

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

(setup 11xx-dired
  (:load-after dired))
(require '11xx-magit)
(setup 11xx-org
  (:load-after org))

(require '11xx-modes)
(require 'llm-ai-assistants)
(require '11xx-pdf-viewer)
