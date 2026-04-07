;; -*- lexical-binding: t; -*-

(setup (:elpaca emmet-mode)
  ;; (:with-map emmet-mode-keymap
  ;;     (:bind ))
  (:hook-into html-mode))

(setup css
  (:option css-indent-offset 2))

(setup (:elpaca web-mode)
  ;; (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.php\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.[agj]sp\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.scss\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
  ;; (:hook-into html-mode css-mode)
  (:hook (:option web-mode-markup-indent-offset 2
                  web-mode-css-indent-offset 2
                  web-mode-code-indent-offset 2
                  web-mode-markup-indent-offset 2
                  web-mode-style-padding 2
                  web-mode-script-padding 2
                  web-mode-enable-auto-closing t
                  web-mode-enable-auto-opening t
                  web-mode-enable-auto-pairing t
                  web-mode-enable-auto-indentation t)))

(setup (:elpaca typescript-mode)
  (:option typescript-indent-level 2)
  (:hook-into js-mode))

(provide '11xx-modes-web)
;;; 11xx-modes-web.el ends here
