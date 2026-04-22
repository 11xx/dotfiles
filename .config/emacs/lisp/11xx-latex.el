;; -*- lexical-binding: t; -*-
(use-package tex-mode
  :ensure nil)

(use-package auctex)

(with-eval-after-load 'ox-html
  (setq org-html-head
        (replace-regexp-in-string
         ".org-svg { width: 90%; }"
         ".org-svg { width: auto; }"
         org-html-style-default)))

(use-package org-fragtog)
