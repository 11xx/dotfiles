;; -*- lexical-binding: t; -*-

;; 'eshell-output-filter-functions void variable means that eshell has to be
;; started once first.
(use-package eshell
  :ensure nil
  :defer t
  :init
  (setq eshell-hist-ignoredups t
        eshell-scroll-to-bottom-on-input t
        eshell-history-size 10000
        eshell-buffer-maximum-lines 2048)
  :config
  (use-package eshell-syntax-highlighting)
  (use-package eshell-git-prompt)
  (add-hook 'eshell-first-time-mode-hook
            (lambda ()
              (add-hook 'eshell-pre-command-hook #'eshell-save-some-history)
              (add-to-list 'eshell-output-filter-functions #'eshell-truncate-buffer))))

(use-package eterm-256color
  :hook (term-mode . eterm-256color-mode)
  :init
  (setq explicit-shell-file-name "bash"))

(use-package multi-vterm
  :defer t)

(provide '11xx-modes-terminal)
;;; 11xx-modes-terminal.el ends here
