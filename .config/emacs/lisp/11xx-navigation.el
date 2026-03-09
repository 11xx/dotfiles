;; -*- lexical-binding: t; -*-
(setup (:elpaca transpose-frame)
  (defun f/rotate-frame-clockwise-or-default ()
    "Rotate frame clockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (window-parent)
        (rotate-frame-clockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  (defun f/rotate-frame-anticlockwise-or-default ()
    "Rotate frame anticlockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (window-parent)
        (rotate-frame-anticlockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  (:global-set
   "M-r" #'f/rotate-frame-clockwise-or-default ;; was #'move-to-window-line-top-bottom
   "M-S-r" #'f/rotate-frame-anticlockwise-or-default ;; was #'move-to-window-line-top-bottom
   ))
(setup (:elpaca multiple-cursors)
  (:global-set
   "C-S-c C-S-c" mc/edit-lines
   "C-<" mc/mark-previous-like-this
   "C->" mc/mark-next-like-this
   "C-c C-<" mc/mark-all-like-this))

(provide '11xx-navigation)
