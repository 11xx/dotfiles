;; -*- lexical-binding: t; -*-

(use-package emmet-mode
  :hook (html-mode . emmet-mode))

(use-package css-mode
  :ensure nil
  :defer t
  :init
  (setq css-indent-offset 2))

(use-package web-mode
  :defer t
  :init
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2
        web-mode-style-padding 2
        web-mode-script-padding 2
        web-mode-enable-auto-closing t
        web-mode-enable-auto-opening t
        web-mode-enable-auto-pairing t
        web-mode-enable-auto-indentation t))

(use-package typescript-mode
  :hook (js-mode . typescript-mode)
  :init
  (setq typescript-indent-level 2))

(provide '11xx-modes-web)
;;; 11xx-modes-web.el ends here
