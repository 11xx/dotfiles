;; -*- lexical-binding: t; -*-
(setup (:elpaca org-pdftools))
(setup (:elpaca pdf-tools)
  ;; (pdf-tools-install)
  (:with-map pdf-view-mode-map
    (:bind "j" pdf-view-next-line-or-next-page
           "k" pdf-view-previous-line-or-previous-page
           ))
  (:with-hook pdf-view-mode-hook
    (:hook pdf-view-themed-minor-mode)))

(provide '11xx-pdf-viewer)
