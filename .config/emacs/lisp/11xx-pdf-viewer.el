;; -*- lexical-binding: t; -*-
(use-package org-pdftools)
(use-package pdf-tools
  :bind (:map pdf-view-mode-map
              ("j" . pdf-view-next-line-or-next-page)
              ("k" . pdf-view-previous-line-or-previous-page))
  :hook (pdf-view-mode . pdf-view-themed-minor-mode))

(provide '11xx-pdf-viewer)
