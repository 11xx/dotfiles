;;; neron-dark-theme.el --- Neron Dark Theme  -*- lexical-binding: t; -*-

;; Author: 11xx
;; Version: 2026-02-26
;; Created: 2022-07-07
;; Keywords: theme dark neon neron low lower contrast

;;; Commentary:

;; Inspired by a very old VSCode theme called Neon Vommit. This theme aims
;; for a lower contrast. The name is a reference to the cypher spelling of
;; Nero, Neron meaning 666, matching the target ratio of 6.66 of this theme.

;; This theme file is inspired in Dracula Theme's Emacs file.

;;; Code:

(require 'neron-theme-base)

(let ((colors
       '((bg-primary      "#222222" "unspecified" "unspecified")
         (bg-secondary    "#27282c" "unspecified" "unspecified")
         (bg-hl           "#2f2f2f" "unspecified" "blue") ; highlights/selection

         (fg-primary      "#a6a8a9" "unspecified" "white")
         (fg-secondary    "#cccccc" "unspecified" "gray")
         (fg-muted        "#707070" "unspecified" "gray") ; comments, weak

         (accent-blue     "#69aaff" "#5fafff" "blue")
         (accent-cyan     "#00bbb7" "#00afaf" "cyan")
         (accent-green    "#61bd09" "#5faf00" "green")
         (accent-magenta  "#ff77cf" "#ff87d7" "magenta")
         (accent-orange   "#fd892c" "#ff8700" "red")
         (accent-purple   "#a89bff" "#afafff" "magenta")
         (accent-red      "#f88785" "#ff8787" "red")
         (accent-warning  "#d2a022" "#d7af00" "red")
         (accent-yellow   "#b8aa07" "#afaf00" "yellow")
         ;; misc/others
         (bg-diff-added   "#152615" "#005f00" "green")
         (bg-diff-removed "#301d1e" "#5f0000" "red")
         (bg-diff-header     "#092147" "blue" "blue")
         (border          "#404047" "#444444" "brightblack")
         (cursor          "#4455bb" "#5f5faf" "blue")
         (comment         "#bda38e" "#afaf87" "yellow")
         ))
      ;; Dark-specific face overrides
      (face-overrides
       '((match :foreground "white" :background bg-hl
                :weight bold :slant i
                :box (:line-width 1 :color border)
                :underline (:style line :position -5))
         (isearch-fail :background "red" :foreground "white" :inherit match)
         (vertico-current :foreground "white" :background bg-hl
                          :weight bold :slant o :extend t)
         (dired-efap-face :foreground "white" :box (:line-width 2 :color border :style pressed-button))
         (show-paren-match :foreground "white" :weight extra-bold)
         (button :foreground "white" :weight semi-bold :underline (:color bg-hl :style double-line)))))

  (neron--create-theme 'dark colors face-overrides))

(provide 'neron-dark-theme)
;;; neron-dark-theme.el ends here
