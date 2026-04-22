;; -*- lexical-binding: t; -*-
(use-package transpose-frame
  :bind (("M-r" . rotate-frame-clockwise-or-default)
         ("M-S-r" . rotate-frame-anticlockwise-or-default))
  :config
  (defun rotate-frame-clockwise-or-default ()
    "Rotate frame clockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (cdr (frame-list))
        (rotate-frame-clockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  (defun rotate-frame-anticlockwise-or-default ()
    "Rotate frame anticlockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (cdr (frame-list))
        (rotate-frame-anticlockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  )
(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
         ("C-<" . mc/mark-previous-like-this)
         ("C->" . mc/mark-next-like-this)
         ("C-c C-<" . mc/mark-all-like-this)))

(provide '11xx-navigation)
