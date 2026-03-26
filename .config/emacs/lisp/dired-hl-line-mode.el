;;; dired-hl-line-mode.el --- Hide block cursor and highlights current line with hl-line -*- lexical-binding: t; -*-

;;; Commentary
;; Minor mode for Dired that hides the block cursor and enables `hl-line'.
;; Automatically transitions in/out when entering wdired or dired-efap for editing.

;;; Code

(require 'hl-line)

(defun dired-hl-line-mode--on ()
  "Enable hl-line and hide cursor."
  (hl-line-mode 1)
  (setq-local cursor-type nil))

(defun dired-hl-line-mode--off ()
  "Disable hl-line and restore cursor."
  (hl-line-mode -1)
  (setq-local cursor-type t))

(defun dired-hl-line-mode--maybe-on (&rest _)
  "Re-enable if mode is active in this buffer."
  (when dired-hl-line-mode
    (dired-hl-line-mode--on)))

(defun dired-hl-line-mode--maybe-off (&rest _)
  "Disable if mode is active in this buffer."
  (when dired-hl-line-mode
    (dired-hl-line-mode--off)))

(define-minor-mode dired-hl-line-mode
  "Toggle hl-line + hidden cursor for read-only Dired browsing."
  :lighter " HlC"
  :group 'dired
  (if dired-hl-line-mode
      (progn
        (add-hook 'wdired-mode-hook #'dired-hl-line-mode--maybe-off nil t)
        (advice-add 'wdired-change-to-dired-mode      :after #'dired-hl-line-mode--maybe-on)
        (advice-add 'dired-efap                       :after #'dired-hl-line-mode--maybe-off)
        (advice-add 'dired-efap--change-to-dired-mode :after #'dired-hl-line-mode--maybe-on)
        (dired-hl-line-mode--on))
    (remove-hook 'wdired-mode-hook                   #'dired-hl-line-mode--maybe-off t)
    (advice-remove 'wdired-change-to-dired-mode      #'dired-hl-line-mode--maybe-on)
    (advice-remove 'dired-efap                       #'dired-hl-line-mode--maybe-off)
    (advice-remove 'dired-efap--change-to-dired-mode #'dired-hl-line-mode--maybe-on)
    (dired-hl-line-mode--off)))

(provide 'dired-hl-line-mode)
;;; dired-hl-line-mode.el ends here
