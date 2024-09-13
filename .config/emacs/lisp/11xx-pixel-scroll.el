(setup pixel-scroll
  ;; (:only-if (display-graphic-p))
  (pixel-scroll-precision-mode)
  (:hook-into elpaca-after-init-hook)
  (:option pixel-scroll-precision-use-momentum t
           pixel-scroll-precision-large-scroll-height 5.0
           mouse-wheel-scroll-amount '(1 ((shift) . 1)) ; one line at a time
           mouse-wheel-progressive-speed nil ; don't accelerate scrolling
           mouse-wheel-follow-mouse 't)) ; scroll window under mouse

(provide '11xx-pixel-scroll)
