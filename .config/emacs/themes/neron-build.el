;; build.el
(require 'neron-gen (expand-file-name "neron-gen.el"))

(defconst neron-dark-colors
  '((bg-primary      "#222222" "unspecified" "unspecified")
    (bg-secondary    "#27282c" "unspecified" "unspecified")
    (bg-hl           "#2f2f2f" "unspecified" "blue")

    (fg-primary      "#a6a8a9" "unspecified" "white")
    (fg-secondary    "#cccccc" "unspecified" "gray")
    (fg-muted        "#707070" "unspecified" "gray")

    (accent-blue     "#69aaff" "#5fafff" "blue")
    (accent-cyan     "#00bbb7" "#00afaf" "cyan")
    (accent-green    "#61bd09" "#5faf00" "green")
    (accent-magenta  "#ff77cf" "#ff87d7" "magenta")
    (accent-orange   "#fd892c" "#ff8700" "red")
    (accent-purple   "#a89bff" "#afafff" "magenta")
    (accent-red      "#f88785" "#ff8787" "red")
    (accent-warning  "#d2a022" "#d7af00" "red")
    (accent-yellow   "#b8aa07" "#afaf00" "yellow")

    (bg-diff-added   "#152615" "#005f00" "green")
    (bg-diff-removed "#301d1e" "#5f0000" "red")
    (bg-diff-header  "#092147" "blue" "blue")
    (border          "#404047" "#444444" "brightblack")
    (cursor          "#4455bb" "#5f5faf" "blue")
    (comment         "#bda38e" "#afaf87" "yellow"))
  "Palette for neron-dark.")

(defconst neron-dark-overrides
  '((match :foreground "white" :background bg-hl
           :weight bold :slant i
           :box (:line-width 1 :color border)
           :underline (:style line :position -5))
    (isearch-fail :background "red" :foreground "white" :inherit match)
    (vertico-current :foreground "white" :background bg-hl
                     :weight bold :slant o :extend t)
    (dired-efap-face :foreground "white"
                     :box (:line-width 2 :color border :style pressed-button))
    (show-paren-match :foreground "white" :weight extra-bold)
    (button :foreground "white" :weight semi-bold
            :underline (:color bg-hl :style double-line)))
  "Face overrides for neron-dark.")

(defconst neron-light-colors
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
    (comment         "#a0a1a7" "#afaf87" "yellow"))
  "Palette for neron-light.")

(defconst neron-light-overrides
  '((match :foreground "black" :background bg-hl
           :weight bold :slant i
           :box (:line-width 1 :color border)
           :underline (:style line :position -5))
    (isearch-fail :background "red" :foreground "black" :inherit match)
    (vertico-current :foreground "black" :background bg-hl
                     :weight bold :slant o :extend t)
    (dired-efap-face :foreground "black"
                     :box (:line-width 2 :color border :style pressed-button))
    (show-paren-match :foreground "black" :weight extra-bold)
    (button :foreground "black" :weight semi-bold
            :underline (:color bg-hl :style double-line)))
  "Face overrides for neron-light.")

(neron-generate-theme 'dark neron-dark-colors neron-dark-overrides)
(neron-generate-theme 'light neron-light-colors neron-light-overrides)
