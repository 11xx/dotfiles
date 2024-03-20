;; source https://www.emacswiki.org/emacs/HalfScrolling
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
;; [next] good-scroll-up-full-screen
;; [prior] good-scroll-down-full-screen
;; Scroll
;; [remap scroll-up-command] scroll-up-half

;; [remap scroll-down-command] scroll-down-half

;; [remap scroll-up-command] pixel-scroll-up
;; [remap scroll-down-command] pixel-scroll-down

(provide '11xx-half-scroll)
