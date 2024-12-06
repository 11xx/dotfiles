;; -*- lexical-binding: t; -*-
(setup tex-mode

(:elpaca auctex)

(with-eval-after-load 'ox-html
  (setq org-html-head
        (replace-regexp-in-string
         ".org-svg { width: 90%; }"
         ".org-svg { width: auto; }"
         org-html-style-default)))

) ; end of (setup tex-mode

(setup (:elpaca org-fragtog))
