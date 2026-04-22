;; -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "modes" user-emacs-directory))

;; Make shebang (#!) file executable when saved
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

(add-to-list 'treesit-extra-load-path
             (expand-file-name "tree-sitter" user-emacs-directory))

(use-package rainbow-mode
  :hook (css-mode . rainbow-mode))

(require '11xx-modes-edit)
(require '11xx-modes-terminal)
(require '11xx-modes-langs)
(require '11xx-modes-special)
(require '11xx-modes-web)

(provide '11xx-modes)
;;; 11xx-modes.el ends here
