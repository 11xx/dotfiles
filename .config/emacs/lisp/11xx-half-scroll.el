;; source https://www.emacswiki.org/emacs/HalfScrolling  -*- lexical-binding: t; -*-
(defun window-half-height ()
  (max 1 (/ (1- (window-height (selected-window))) 2)))

(cl-defun window-div-height (&optional (n 2))
  (max 1 (/ (1- (window-height (selected-window))) n)))

(defun scroll-up-half ()
  (interactive)
  (scroll-up (window-half-height)))

(defun scroll-down-half ()
  (interactive)
  (scroll-down (window-half-height)))

;;;###autoload
(defun scroll-up-div ()
  (interactive)
  (scroll-up (window-div-height 10)))

;;;###autoload
(defun scroll-down-div ()
  (interactive)
  (scroll-down (window-div-height 10)))

(keymap-global-set "<remap> <scroll-up-command>" #'scroll-up-div)
(keymap-global-set "<remap> <scroll-down-command>" #'scroll-down-div)

(provide '11xx-half-scroll)
