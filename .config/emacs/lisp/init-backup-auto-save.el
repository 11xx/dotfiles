;; -*- lexical-binding: t; -*-
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

;; ;; add random number to auto save file list
;; (defun f/auto-save-list-file-name-function ()
;;   (let ((basename (concat 11xx--auto-save-directory "/auto-save-list-"))
;;         (random-number (number-to-string (random))))
;;     (concat basename (substring random-number 0 8) "~")))
;; (setq auto-save-list-file-name-function #'f/auto-save-list-file-name-function)

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

(provide 'init-backup-auto-save)

(setopt create-lockfiles nil)
