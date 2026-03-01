;;; neron-light-theme.el --- Neron Light Theme  -*- lexical-binding: t; -*-

;; Author: 11xx
;; Version: 2026-02-26
;; Created: 2023-02-25
;; Keywords: theme light neon neron low lower contrast

;;; Commentary:

;; Inspired by a very old VSCode theme called Neon Vommit. This theme aims
;; for a lower contrast. The name is a reference to the cypher spelling of
;; Nero, Neron meaning 666, matching the target ratio of 6.66 of this theme.

;; This theme file is inspired in Dracula Theme's Emacs file.

;;; Code:

(require 'neron-theme-base)

(let ((colors
       '((bg-primary      "#ffffff" "unspecified" "unspecified")
         (bg-secondary    "#f6f6f6" "unspecified" "unspecified")
         (bg-hl           "#fdf6df" "unspecified" "blue") ; highlights/selection

         (fg-primary      "#545e62" "unspecified" "white")
         (fg-secondary    "#cccccc" "unspecified" "gray")
         (fg-muted        "#868787" "unspecified" "gray") ; comments, weak

         (accent-blue     "#0353c6" "#5fafff" "blue")
         (accent-cyan     "#006861" "#00afaf" "cyan")
         (accent-green    "#316900" "#5faf00" "green")
         (accent-orange   "#964505" "#ff8700" "red")
         (accent-magenta  "#b30071" "#ff87d7" "magenta")
         (accent-purple   "#4d2eff" "#afafff" "magenta")
         (accent-red      "#ba0d0d" "#ff8787" "red")
         (accent-warning  "#7a5524" "#d7af00" "red")
         (accent-yellow   "#615f0b" "#afaf00" "yellow")
         ;; misc/other
         (bg-diff-added   "#d5ffd5" "#005f00" "green")
         (bg-diff-removed "#ffd4d4" "#5f0000" "red")
         (bg-diff-header  "pale turquoise" "blue" "blue")
         (border          "light gray" "#444444" "brightblack")
         (cursor          "#3d51c2" "#5f5faf" "blue")
         (comment         "#a0a1a7" "#afaf87" "yellow")))

      (face-overrides
       '((match :foreground "black" :background bg-hl
                :weight bold :slant i
                :box (:line-width 1 :color border)
                :underline (:style line :position -5))
         (isearch-fail :background "red" :foreground "black" :inherit match)
         (vertico-current :foreground "black" :background bg-hl
                          :weight bold :slant o :extend t)
         (dired-efap-face :foreground "black" :box (:line-width 2 :color border :style pressed-button))
         (show-paren-match :foreground "black" :weight extra-bold)
         (button :foreground "black" :weight semi-bold :underline (:color bg-hl :style double-line)))))

  (neron--create-theme 'light colors face-overrides))

(provide 'neron-light-theme)
;;; neron-light-theme.el ends here
