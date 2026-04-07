;; -*- lexical-binding: t; -*-

;; 'eshell-output-filter-functions void variable means that eshell has to be
;; started once first.
(setup eshell (:elpaca eshell-syntax-highlighting)
       (:elpaca eshell-git-prompt)
       (setopt eshell-hist-ignoredups t
               eshell-scroll-to-bottom-on-input t
               eshell-history-size 10000
               eshell-buffer-maximum-lines 2048)
       (:with-hook eshell-first-time-mode-hook
         (:hook (lambda() (add-hook 'eshell-pre-command-hook 'eshell-save-some-history)
                  (add-to-list 'eshell-output-filter-functions 'eshell-truncate-buffer)))))

(setup term (:elpaca eterm-256color)
       (:option explicit-shell-file-name "bash")
       (:with-mode eterm-256color-mode
         (:hook-into term-mode)))

(setup (:elpaca multi-vterm))

(provide '11xx-modes-terminal)
;;; 11xx-modes-terminal.el ends here
