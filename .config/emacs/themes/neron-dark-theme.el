;;; neron-dark-theme.el --- Draco-Neo-Vom Theme  -*- lexical-binding: t; -*-

;; The MIT License (MIT)

;; Copyright (c) 2015-present Dracula Theme

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

;; Also known as neron-vommit :d # [2022-07-07 Thu 23:09:38 -03]
;; changed/renamed to neron-dark # [2022-08-11 Thu 23:11:18 -03]

;;; Commentary:
;; This just and edited Emacs dracula-theme.el file
;; The original is at https://raw.githubusercontent.com/dracula/emacs/master/dracula-theme.el
;; Version 0.5

;;; Code:
(deftheme neron-dark)

;;;; Configuration options:

(defgroup neron-dark nil
  "\"neron-dark\" theme options.

The theme has to be reloaded after changing anything in this group."
  :group 'faces)

(defcustom neron-dark-enlarge-headings t
  "Use different font sizes for some headings and titles."
  :type 'boolean
  :group 'neron-dark)

(defcustom neron-dark-height-title-1 1.3
  "Font size 100%."
  :type 'number
  :group 'neron-dark)

(defcustom neron-dark-height-title-2 1.1
  "Font size 110%."
  :type 'number
  :group 'neron-dark)

(defcustom neron-dark-height-title-3 1.0
  "Font size 130%."
  :type 'number
  :group 'neron-dark)

(defcustom neron-dark-height-doc-title 1.44
  "Font size 144%."
  :type 'number
  :group 'neron-dark)

(defcustom neron-dark-alternate-mode-line-and-minibuffer nil
  "Use less bold and pink in the minibuffer."
  :type 'boolean
  :group 'neron-dark)

(defvar neron-dark-use-24-bit-colors-on-256-colors-terms nil
  "Use true colors even on terminals announcing less capabilities.

Beware the use of this variable.  Using it may lead to unwanted
behavior, the most common one being an ugly blue background on
terminals, which don't understand 24 bit colors.  To avoid this
blue background, when using this variable, one can try to add the
following lines in their config file after having load the
neron-dark theme:

    (unless (display-graphic-p)
      (set-face-background 'default \"black\" nil))

There is a lot of discussion behind the 256 colors theme (see URL
`https://github.com/dracula/emacs/pull/57').  Please take time to
read it before opening a new issue about your will.")



;;;; Theme definition:
;; #ff00aa
;; #FF6bFe
;; #FF6dF8
;; #FF6bff
;; #ff77cf ; old
;; #bba909
;; #b8aa07 ; old
;; #00bbb7 ;n
;; #16b8cf
;; #69aaff n
;; #63abff
;; Assigment form: VARIABLE COLOR [256-COLOR [TTY-COLOR]]
(let ((colors '(;; Upstream theme color
                (c/bg      "#222222" "unspecified-bg" "unspecified-bg") ; official background
                (c/fg      "#a6a8a9" "#afafaf" "white")                 ; official foreground
                (c/current "#2f2f2f" "#000000" "blue")                  ; official current-line/selection
                (c/comment "#bda38e" "#afaf87" "yellow")                ; official comment
                (c/cyan    "#00bbb7" "#00afaf" "cyan")                  ; official cyan
                (c/green   "#61bd09" "#5faf00" "green")                 ; official green
                (c/orange  "#fd892c" "#ff8700" "red")                   ; both official orange
                (c/pink    "#ff77cf" "#ff87d7" "magenta")               ; official pink
                (c/purple  "#a89bff" "#afafff" "magenta")               ; official purple
                (c/red     "#f88785" "#ff8787" "red")                   ; official red
                (c/yellow  "#b8aa07" "#afaf00" "yellow")                ; official yellow
                (c/blue    "#69aaff" "#5fafff" "blue")
                (c/cursor  "#4455bb" "#5f5faf" "blue")                  ;; :inverse-video nil
                ;; (c/cursor  "#5f5faf" "#5f5faf" "blue")                  ;; :inverse-video nil
                ;; (c/cursor "#9ca5d8")
                (c/warning "#d2a022" "#d7af00" "red")                   ;both
                                                                        ;; Other colors
                (c/invisible-fg "#707070" "#5f5f5f" "white")            ; "invisible" foreground colour
                (c/invisible-bg "#292827" "#000000" "black")            ; also 616 ratio
                (c/bg-term-pink "#2a1e2b" "#000000" "black")            ; based off of c/pink im pretty sure :s
                ;; (bg2             "#333333" "#343434" "brightblack") ; was using this [2022-12-12 Mon 15:19:06 -03]
                ;; (bg3             "#1c1c1c")
                ;; (bg3         "#1F2130") ; based off of doom-palenight org-block face
                (c/bg-term-green "#18251b" "#000000" "black")           ; based terminal neovom
                ;;         background: '#18251b'
                (c/bg-616           "#27282c")                          ; 616 ratio
                (c/white "#929595" "#878787" "white")
                (c/black "#414a44" "#5f5f5f" "black")
                (c/bg-diff-added "#152615" "#005f00" "green")
                (c/bg-diff-removed "#301d1e" "#ff8787" "red")
                ))

      (faces '(;; default / basic faces
               (cursor :background ,c/cursor :foreground ,c/fg :inverse t)
               (default :background ,c/bg :foreground ,c/fg)
               (default-italic :slant italic)
               (error :foreground ,c/red)
               (tooltip :foreground ,c/fg :background ,c/current)
               (fringe :background ,c/bg) ; had bg2
               ;; modeline
               ;; (doom-modeline-buffer-modified :weight bold)
               (mode-line :background ,c/bg-616) ; had bg2
               ;; (mode-line-active)
               ;; (mode-line-emphasis)
               (mode-line-inactive :backgroun ,c/bg)
               ;; (mode-line-buffer-id)
               ;; (mode-line-highlight)
               (doom-modeline-lsp-success :foreground ,c/green)
               ;; (doom-modeline-bar "unspecified-bg")
               ;; (doom-modeline-bar-inactive "unspecified-bg")
               (tab-bar :background ,c/bg)
               ;; (tab-line :inherit mode-line-inactive)
               (tab-bar-tab :background ,c/current)
               (tab-bar-tab-inactive :background ,c/bg)
               ;; (tab-bar-tab-group-inactive :inherit tab-bar)
               (custom-button-mouse :background ,c/bg :foreground ,c/fg)
               (custom-button :background ,c/bg :foreground ,c/fg)
               (custom-button-pressed :inherit custom-buttom)

               (shadow :foreground ,c/comment)
               (highlight :foreground ,c/bg :background ,c/comment :weight bold :inverse t)
               (match :foreground "white" :slant italic)
               (region :foreground "white" :background ,c/current)
               (vertical-border :foreground ,c/current) ; window/buffer divider line
               (window-divider :foreground "gray20") ; window-divider-mode
               (window-divider-first-pixel :inherit window-divider)
               (window-divider-last-pixel :inherit window-divider)

               ;; ace-window
               (aw-leading-char-face :foreground ,c/red :height 300)
               ;; isearch, also inherited by consult
               (isearch :background ,c/pink :foreground ,c/bg :weight extra-bold)
               (isearch-fail :background ,c/red :foreground ,c/bg)
               ;; Parens
               (show-paren-match :foreground "white" :weight extra-bold)
               ;; syntax highlighting
               (font-lock-builtin-face :foreground ,c/pink)
               (font-lock-comment-delimiter-face :foreground ,c/comment)
               (font-lock-comment-face :foreground ,c/comment)
               (font-lock-constant-face :foreground ,c/blue)
               (font-lock-doc-face :foreground ,c/purple)
               (font-lock-doc-markup-face :foreground ,c/purple)
               (font-lock-function-name-face :foreground ,c/green)
               (font-lock-keyword-face :foreground ,c/pink)
               (font-lock-negation-char-face :foreground ,c/yellow)
               (font-lock-preprocessor-face :foreground ,c/pink)
               (font-lock-regexp-grouping-backslash :foreground ,c/blue)
               (font-lock-regexp-grouping-construct :foreground ,c/blue)
               (font-lock-string-face :foreground ,c/purple) ; was c/purple but it would have too low contrast with c/fg
               (font-lock-type-face :foreground ,c/cyan)
               (font-lock-variable-name-face :foreground ,c/fg)
               (font-lock-warning-face :foreground ,c/warning)
               ;; buttons
               (link :foreground ,c/fg :underline t :weight bold)
               ;; whitespace / indentation / general text editing
               (trailing-whitespace :background ,c/red)
               (whitespace-tab :background "#330022")
               ;; guides / rulers
               (fill-column-indicator :foreground ,c/current)
               ;; sh mode
               (sh-heredoc :foreground ,c/orange) ; was purple, same as string-face
               ;; (sh-heredoc undefined)
               (sh-quoted-exec :foreground ,c/red)
               ;; vertico
               ;; (vertico-current :foreground "white" :background ,c/cursor :weight bold)
               (vertico-current :foreground "white" :background "#333333" :slant o :weight bold)
               ;; consult
               ;; (consult-preview-match )
               ;; orderless
               (orderless-match-face-0 :foreground ,c/blue :weight bold)
               (orderless-match-face-1 :foreground ,c/pink :weight bold)
               (orderless-match-face-2 :foreground ,c/green :weight bold)
               (orderless-match-face-3 :foreground ,c/yellow :weight bold)
               ;; corfu
               (corfu-default :background ,c/bg-616)
               (corfu-bar :background ,c/invisible-fg)
               (corfu-border :background ,c/comment)
               (corfu-current :inherit vertico-current)
               ;; (corfu-annotations)
               ;; (corfu-deprecated)
               (orderless-match-face-0 :foreground "white" :slant italic)

               (marginalia-documentation :inherit font-lock-string-face)

               ;; org
               (org-block :background ,c/bg-616)
               (org-block-begin-line :inherit org-block :foreground ,c/invisible-fg)
               (org-block-end-line :inherit org-block-begin-line)
               (org-date :foreground ,c/cyan)
               (outline-1 :extend t :foreground ,c/pink :weight bold :height 200)
               (outline-2 :extend t :foreground ,c/green :weight bold :height 180)
               (outline-3 :extend t :foreground ,c/cyan :weight bold :height 160)
               (outline-4 :extend t :foreground ,c/red :weight bold :height 140)
               (outline-5 :extend t :foreground ,c/purple :weight bold :height 130)
               (outline-6 :extend t :foreground ,c/pink :weight bold :height 120)
               (outline-7 :extend t :foreground ,c/green :weight bold :height 110)
               (outline-8 :extend t :foreground ,c/cyan :weight bold :height 100)
               (org-verbatim :foreground ,c/warning)
               (org-code :foreground ,c/warning)
               (org-drawer :foreground ,c/invisible-fg)
               (org-ellipsis :foreground unspecified)
               ;; (org-num-face :foreground unspecified :height 80)
               ;; dired
               (dired-rainbow-directory-face        :foreground ,c/blue)
               (dired-rainbow-html-face             :foreground ,c/red)
               (dired-rainbow-xml-face              :foreground ,c/yellow)
               (dired-rainbow-document-face         :foreground ,c/purple)
               (dired-rainbow-markdown-face         :foreground ,c/pink)
               (dired-rainbow-database-face         :foreground ,c/blue)
               (dired-rainbow-media-face            :foreground ,c/purple)
               (dired-rainbow-image-face            :foreground ,c/purple)
               (dired-rainbow-log-face              :foreground ,c/warning)
               (dired-rainbow-shell-face            :foreground ,c/green)
               (dired-rainbow-interpreted-face      :foreground ,c/green)
               (dired-rainbow-compiled-face         :foreground ,c/green)
               (dired-rainbow-executable-face       :foreground ,c/green)
               (dired-rainbow-compressed-face       :foreground ,c/red)
               (dired-rainbow-packaged-face         :foreground ,c/purple)
               (dired-rainbow-encrypted-face        :foreground ,c/yellow)
               (dired-rainbow-fonts-face            :foreground ,c/blue)
               (dired-rainbow-partition-face        :foreground ,c/red)
               (dired-rainbow-vc-face               :foreground ,c/blue)
               (dired-rainbow-executable-unix-face  :foreground ,c/green)
               ;; all-the-icons
               (all-the-icons-dired-dir-face :foreground ,c/blue)
               ;; diredfl
               (diredfl-compressed-file-name :foreground ,c/red)                       ;; *Face used for compressed file names.
               (diredfl-compressed-file-suffix :inherit diredfl-compressed-file-name)  ;; *Face used for compressed file suffixes in Dired buffers. This means the ‘.’ plus the file extension.  Example: ‘.zip’.
               (diredfl-mode-set-explicitly :inherit default)                          ;; Basic default face.
               (diredfl-number :foreground ,c/cyan)                                    ;; *Face used for numerical fields in Dired buffers. In particular, inode number, number of hard links, and file size.
               (diredfl-no-priv :inherit diredfl-mode-set-explicitly)                  ;; *Face used for no privilege indicator (-) in Dired buffers.
               (diredfl-dir-name :foreground ,c/blue)                                  ;; *Face used for directory names.
               (diredfl-dir-priv :inherit diredfl-dir-name)                            ;; *Face used for directory privilege indicator (d) in Dired buffers.
               (diredfl-date-time :foreground ,c/blue)                                 ;; *Face used for date and time in Dired buffers.
               (diredfl-executable-tag :foreground ,c/green)                           ;; *Face used for executable tag (*) on file names in Dired buffers.
               (diredfl-exec-priv :inherit diredfl-executable-tag)                     ;; *Face used for execute privilege indicator (x) in Dired buffers.
               (diredfl-file-name :foreground ,c/fg)                                   ;; *Face used for file names (without suffixes) in Dired buffers. This means the base name.  It does not include the ‘.’.
               (diredfl-symlink :foreground ,c/cyan)                                   ;; *Face used for symbolic links in Dired buffers.
               (diredfl-link-priv :inherit diredfl-symlink)                            ;; *Face used for link privilege indicator (l) in Dired buffers.
               (diredfl-rare-priv :foreground ,c/pink)                                 ;; *Face used for rare privilege indicators (b,c,s,m,p,S) in Dired buffers.
               (diredfl-read-priv :foreground ,c/yellow)                               ;; *Face used for read privilege indicator (w) in Dired buffers.
               (diredfl-other-priv :foreground ,c/warning)                             ;; *Face used for l,s,S,t,T privilege indicators in Dired buffers.
               (diredfl-write-priv :foreground ,c/red)                                 ;; *Face used for write privilege indicator (w) in Dired buffers.
               (diredfl-dir-heading :inherit font-lock-comment-face :background ,c/bg) ;; *Face used for directory headings in Dired buffers.
               (diredfl-file-suffix undefined)                                         ;; *Face used for file suffixes in Dired buffers. This means the ‘.’ plus the file extension.  Example: ‘.elc’.
               ;; (diredfl-autofile-name :inherit )                                    ;; *Face used in Dired for names of files that are autofile bookmarks.
               ;; (diredfl-tagged-autofile-name :inherit dired-rainbow-compressed-face) ;; *Face used in Dired for names of files that are autofile bookmarks.
               (diredfl-flag-mark-line :background ,c/cursor)                          ;; *Face used for flagged and marked lines in Dired buffers.
               (diredfl-flag-mark :inherit diredfl-flag-mark-line)                     ;; *Face used for flags and marks (except D) in Dired buffers.
               (diredfl-ignored-file-name :inherit font-lock-comment-face)             ;; *Face used for ignored file names  in Dired buffers.
               (diredfl-deletion-file-name :background ,c/red :foreground ,c/bg)       ;; *Face used for names of deleted files in Dired buffers.
               (diredfl-deletion :inherit diredfl-deletion-file-name)                  ;; *Face used for deletion flags (D) in Dired buffers.
               ;; dired-efap / rename
               ;; (dired-efap-face :height 140 :box (:line-width 2 :color "grey20" :style pressed-button))

               ;; tree-sitter
               (tree-sitter-hl-face:attribute :inherit font-lock-constant-face)
               (tree-sitter-hl-face:comment :inherit font-lock-comment-face)
               (tree-sitter-hl-face:constant :inherit font-lock-constant-face)
               (tree-sitter-hl-face:constant.builtin :inherit font-lock-builtin-face)
               (tree-sitter-hl-face:constructor :inherit font-lock-constant-face)
               (tree-sitter-hl-face:escape :foreground ,c/pink)
               (tree-sitter-hl-face:function :inherit font-lock-function-name-face)
               (tree-sitter-hl-face:function.builtin :inherit font-lock-builtin-face)
               (tree-sitter-hl-face:function.call :inherit font-lock-function-name-face :weight normal)
               (tree-sitter-hl-face:function.macro :inherit font-lock-preprocessor-face)
               (tree-sitter-hl-face:function.special :inherit font-lock-preprocessor-face)
               (tree-sitter-hl-face:keyword :inherit font-lock-keyword-face)
               (tree-sitter-hl-face:punctuation :foreground ,c/pink)
               (tree-sitter-hl-face:punctuation.bracket :foreground ,c/fg)
               (tree-sitter-hl-face:punctuation.delimiter :foreground ,c/fg)
               (tree-sitter-hl-face:punctuation.special :foreground ,c/pink)
               (tree-sitter-hl-face:string :inherit font-lock-string-face)
               (tree-sitter-hl-face:string.special :foreground ,c/red)
               (tree-sitter-hl-face:tag :inherit font-lock-keyword-face)
               (tree-sitter-hl-face:type :inherit font-lock-type-face)
               (tree-sitter-hl-face:type.parameter :foreground ,c/pink)
               (tree-sitter-hl-face:variable :inherit font-lock-variable-name-face)
               (tree-sitter-hl-face:variable.parameter :inherit tree-sitter-hl-face:variable :weight normal)
               ;; web-mode
               (web-mode-builtin-face :inherit font-lock-builtin-face)
               (web-mode-comment-face :inherit font-lock-comment-face)
               (web-mode-constant-face :inherit font-lock-constant-face)
               (web-mode-css-property-name-face :inherit font-lock-constant-face)
               (web-mode-doctype-face :inherit font-lock-comment-face)
               (web-mode-function-name-face :inherit font-lock-function-name-face)
               (web-mode-html-attr-name-face :foreground ,c/purple)
               (web-mode-html-attr-value-face :foreground ,c/green)
               (web-mode-html-tag-face :foreground ,c/pink :weight bold)
               (web-mode-keyword-face :foreground ,c/pink)
               (web-mode-string-face :foreground ,c/yellow)
               (web-mode-type-face :inherit font-lock-type-face)
               (web-mode-warning-face :inherit font-lock-warning-face)

               ;; ANSI colors
               ;; This is where eshell gets colours from

               ;; brigh version from alacritty 666dark:

               (ansi-color-red :foreground ,c/red)
               (ansi-color-blue :foreground ,c/blue)
               (ansi-color-cyan :foreground ,c/cyan)
               (ansi-color-black :foreground ,c/black)
               (ansi-color-green :foreground ,c/green)
               (ansi-color-white :foreground ,c/fg)
               (ansi-color-yellow :foreground ,c/yellow)
               (ansi-color-magenta :foreground ,c/pink)
               ;; (ansi-color-italic :foreground ,c/)
               ;; (ansi-color-inverse :foreground ,c/)
               ;; (ansi-color-underline :foreground ,c/)
               ;; (ansi-color-bold :foreground ,c/)
               ;; (ansi-color-faint :foreground ,c/)

               ;; #TODO add or conventionalize(?) these special colors:
               (ansi-color-bright-red :foreground "#e88e8c")
               (ansi-color-bright-blue :foreground "#70aaee")
               (ansi-color-bright-cyan :foreground "#33aec7")
               (ansi-color-bright-black :foreground "#555d58")
               (ansi-color-bright-green :foreground "#6fb922")
               (ansi-color-bright-white :foreground "#a6a8a9")
               (ansi-color-bright-yellow :foreground "#b4aa27")
               (ansi-color-bright-magenta :foreground "#ed81c7")
               ;; (ansi-color-fast-blink :foreground ,c/)
               ;; (ansi-color-slow-blink :foreground ,c/)


               ;; vterm
               (vterm-color-red :inherit ansi-color-red)
               (vterm-color-blue :inherit ansi-color-blue)
               (vterm-color-cyan :inherit ansi-color-cyan)
               (vterm-color-black :inherit ansi-color-black)
               (vterm-color-green :inherit ansi-color-green)
               (vterm-color-white :inherit ansi-color-white)
               (vterm-color-yellow :inherit ansi-color-yellow)
               (vterm-color-magenta :inherit ansi-color-magenta)
               ;; (vterm-color-underline :foreground ,c/)
               ;; (vterm-color-inverse-video :foreground ,c/)

               ;; diff
               ;; (diff-header :foreground "#e5e7e8" :background "#4f4e51") ;; 1282 -> 666
               ;; (diff-file-header :inherit diff-header :background "#092147")
               (diff-header :background "#092147")
               (diff-file-header :inherit diff-header)
               (diff-added :background "#022900")
               ;; (diff-indicator-added :inherit diff-added :foreground "#91ff93") ;; 1282
               ;; (diff-indicator-added :inherit diff-added :foreground "#00c241") ;; custom foreground
               (diff-indicator-added :inherit diff-added :foreground ,c/green)
               (diff-removed :background ,c/bg-diff-removed)
               ;; (diff-indicator-removed :inherit diff-removed :foreground "#ff8287") ;; custom foreground
               (diff-indicator-removed :inherit diff-removed :foreground ,c/red)
               (diff-refine-added :inherit diff-added) ;; 1282
               (diff-refine-removed :inherit diff-removed) ;; 1282
               ;; (diff-error :background ,c/)
               ;; (diff-index :background ,c/)
               ;; (diff-header :background ,c/)
               ;; (diff-changed :background ,c/)
               ;; (diff-context :background ,c/)
               ;; (diff-function :background ,c/)
               ;; ediff
               (ediff-current-diff-A :inherit diff-removed)
               (ediff-fine-diff-A :inherit diff-refine-removed) ; :foreground ,dracula-fg)
               (ediff-current-diff-B :inherit diff-added)
               (ediff-fine-diff-B :inherit diff-refine-added) ; :foreground ,dracula-bg)
               (ediff-current-diff-C :background "#018840") ; temp color
               (ediff-fine-diff-C :background ,c/cyan) ; :foreground ,dracula-bg)
               (ediff-odd-diff-A :inherit diff-header)
               (ediff-even-diff-A :inherit diff-header)
               (ediff-odd-diff-B :inherit diff-header)
               (ediff-even-diff-B :inherit diff-header)
               (ediff-odd-diff-C :inherit diff-header)
               (ediff-even-diff-C :inherit diff-header)
               ;; magit
               (magit-diff-added :inherit diff-added)
               (magit-diffstat-added :inherit diff-indicator-added)
               (magit-diff-added-highlight :inherit diff-added)
               (magit-diff-removed :inherit diff-removed)
               (magit-diffstat-removed :inherit diff-indicator-removed)
               (magit-diff-removed-highlight :inherit diff-removed)
               (magit-section-highlight :background ,c/current)
               (magit-diff-context-highlight :background ,c/current)
               (magit-diff-hunk-heading :inherit diff-header)
               (magit-diff-hunk-heading-highlight :inherit magit-diff-hunk-heading)

               ;; ansible
               (ansible-task-label-face :foreground ,c/green)

               ;; lsp-mode
               (lsp-face-highlight-read :weight extra-bold :underline t)
               (lsp-face-highlight-write :inherit lsp-face-highlight-read :underline nil)

               ;; Indent highlight guide
               (highlight-indent-guides-even-face :foreground ,c/current :background ,c/current)
               (highlight-indent-guides-odd-face :foreground ,c/current :background ,c/current)
               (highlight-indent-guides-top-odd-face :foreground ,c/current :background ,c/current)
               (highlight-indent-guides-top-even-face :foreground ,c/current :background ,c/current)
               (highlight-indent-guides-character-face :foreground ,c/current :background ,c/current)
               (highlight-indent-guides-stack-odd-face :foreground ,c/current :background ,c/current)

               ;; Flycheck errors
               (flycheck-error :underline (:style wave :color ,c/pink))

               ;; Package-manager interactive UI
               (elpaca-finished :foreground ,c/green :weight bold)

               ;; Eldoc
               (eldoc-box-border :background ,c/purple)
               )))

  (apply #'custom-theme-set-faces 'neron-dark
         (let ((expand-with-func
                (lambda (func spec)
                  (let (reduced-color-list)
                    (dolist (col colors reduced-color-list)
                      (push (list (car col) (funcall func col))
                            reduced-color-list))
                    (eval `(let ,reduced-color-list
                             (backquote ,spec))))))
               whole-theme)
           (pcase-dolist (`(,face . ,spec) faces)
             (push `(,face
                     ((((min-colors 16777216)) ; fully graphical envs
                       ,(funcall expand-with-func 'cadr spec))
                      (((min-colors 256))      ; terminal withs 256 colors
                       ,(if neron-dark-use-24-bit-colors-on-256-colors-terms
                            (funcall expand-with-func 'cadr spec)
                          (funcall expand-with-func 'caddr spec)))
                      (t                       ; should be only tty-like envs
                       ,(funcall expand-with-func 'cadddr spec))))
                   whole-theme))
           whole-theme))
  )

(provide-theme 'neron-dark)

;;; neron-dark-theme.el ends here
