;; -*- lexical-binding: t; -*-
(defvar config-lisp-directory
  (expand-file-name "lisp/" user-emacs-directory)
  "Directory containing local configuration Lisp source files.")

(add-to-list 'load-path config-lisp-directory)

(require 'elpaca-bootstrap)

(require '11xx-setup)

(require 'clean-emacs-user-directory)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(setq gc-cons-threshold (* 500 1024 1024))
(add-hook 'elpaca-after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

(defun loaddefs-setup (&optional lisp-dir)
  "Ensure autoloads for LISP-DIR are current, then load them.

Scans LISP-DIR (default: `config-lisp-directory') for `;;;###autoload'
cookies via `loaddefs-generate', skipping regeneration when the output
file is newer than all source files.  The generated file is stored in
`no-littering-var-directory' and LISP-DIR is added to `load-path'."
  (require 'cl-lib)
  (let* ((dir (file-truename (or lisp-dir config-lisp-directory)))
         (out (expand-file-name "config-loaddefs.el"
                                no-littering-var-directory))
         (sources (directory-files dir t "\\.el\\'"))
         (out-attrs (and (file-exists-p out) (file-attributes out)))
         (out-mtime  (and out-attrs
                          (file-attribute-modification-time out-attrs))))
    (add-to-list 'load-path dir)
    (when (or (not out-mtime)
              (cl-some (lambda (f)
                         (time-less-p
                          out-mtime
                          (file-attribute-modification-time
                           (file-attributes f))))
                       sources))
      (loaddefs-generate dir out))
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
