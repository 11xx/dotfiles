;; -*- lexical-binding: t; -*-

(define-minor-mode sensitive-mode
  "For sensitive files like password lists.
It disables backup creation and auto saving.

With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode."
  ;; The initial value.
  :init-value nil
  ;; The indicator for the mode line.
  :lighter " Sensitive"
  ;; The minor mode bindings.
  :keymap nil
  ;; added keywords instead of deprecated positional arguments:
  ;; fix for "Warning: Use keywords rather than deprecated positional
  ;; arguments to `define-minor-mode'" # [2022-11-11 Fri 16:09:40 -03]
  ;; See the commits from [[https://github.com/purcell/emacs.d/issues/780][Use keywords rather than positional arguments to define-minor-mode · Issue #780 · purcell/emacs.d]]

  (if (symbol-value sensitive-mode)
      (progn
        ;; disable backups
        (set (make-local-variable 'backup-inhibited) t)
        ;; disable auto-save
        (if auto-save-default
            (auto-save-mode -1)))
                                        ;resort to default value of backup-inhibited
    (kill-local-variable 'backup-inhibited)
                                        ;resort to default auto save setting
    (if auto-save-default
        (auto-save-mode 1))))

(provide '11xx-modes-special)
;;; 11xx-modes-special.el ends here
