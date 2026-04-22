;; -*- lexical-binding: t; -*-

(use-package haskell-mode)

(use-package cc-mode
  :ensure nil
  :init
  (setq c-default-style '((java-mode . "java")
                          (awk-mode  . "awk")
                          (other     . "k&r"))
        c-basic-offset 2))

(defun org-babel-execute:c-ts (body params)
  "Execute a block of `c-ts-mode' as `c-mode' with Org Babel."
  (org-babel-execute:C body params))

(use-package ob-rust
  :after org)

(use-package ron-mode
  :mode "*.ron")

(use-package lua-mode)

(provide '11xx-modes-langs)
;;; 11xx-modes-langs.el ends here
