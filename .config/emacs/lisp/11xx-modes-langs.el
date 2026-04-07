;; -*- lexical-binding: t; -*-

(setup (:elpaca haskell-mode))

(setup cc-mode
  (setopt c-default-style '((java-mode . "java")
                            (awk-mode  . "awk")
                            (other     . "k&r"))
          c-basic-offset 2))

(defun org-babel-execute:c-ts (body params)
  "Execute a block of `c-ts-mode' as `c-mode' with Org Babel."
  (org-babel-execute:C body params))

(setup (:elpaca ob-rust)
  (:load-after org))

(setup ron-mode
  (:elpaca ron-mode)
  (:autoload ron-mode)
  (:match-file "*.ron"))

(setup (:elpaca lua-mode))

(provide '11xx-modes-langs)
;;; 11xx-modes-langs.el ends here
