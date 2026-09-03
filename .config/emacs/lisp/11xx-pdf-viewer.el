;; -*- lexical-binding: t; -*-
(use-package pdf-tools
  :init (pdf-loader-install)
  :bind (:map pdf-view-mode-map
              ("j" . pdf-view-next-line-or-next-page)
              ("k" . pdf-view-previous-line-or-previous-page))
  :hook (pdf-view-mode . pdf-view-themed-minor-mode))

(use-package org-pdftools
  :defer t
  :init
  (with-eval-after-load 'org
    (org-link-set-parameters "pdf"
                             :follow #'org-pdftools-open
                             :complete #'org-pdftools-complete-link
                             :store #'org-pdftools-store-link
                             :export #'org-pdftools-export)))

(provide '11xx-pdf-viewer)
