;; -*- lexical-binding: t; -*-
(setq gc-cons-threshold (* 1000 8 2 100)) ; (* 1000 8) (8KB) is the default
(add-hook 'after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

(provide '11xx-gc)
