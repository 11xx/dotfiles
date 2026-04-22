;; -*- lexical-binding: t; -*-
(use-package pixel-scroll
  :ensure nil
  :hook (after-init . pixel-scroll-precision-mode)
  :init
  (setq pixel-scroll-precision-use-momentum t
        pixel-scroll-precision-large-scroll-height 5.0
        mouse-wheel-scroll-amount '(1 ((shift) . 1))
        mouse-wheel-progressive-speed nil
        mouse-wheel-follow-mouse t))

(provide '11xx-pixel-scroll)
