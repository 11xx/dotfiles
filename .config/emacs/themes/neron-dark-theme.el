;;; neron-dark-theme.el --- Neron Dark Theme  -*- lexical-binding: t; -*-

;; Keywords: theme dark neon neron

;;; Commentary:

;; Generated file — standalone and editable.
;; To regenerate: emacs -Q --script build.el

;;; Code:

(deftheme neron-dark)

;;;; Configuration options

(defgroup neron-dark nil
  "\"neron-dark\" theme options.
The theme has to be reloaded after changing anything in this group."
  :group 'faces)

(defcustom neron-dark-enlarge-headings t
  "Use different font sizes for some headings and titles."
  :type 'boolean
  :group 'neron-dark)

(defcustom neron-dark-height-title-1 1.3
 "Font size 130%."
 :type 'number
 :group 'neron-dark)

(defcustom neron-dark-height-title-2 1.1
 "Font size 110%."
 :type 'number
 :group 'neron-dark)

(defcustom neron-dark-height-title-3 1.0
 "Font size 100%."
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

(let ((colors '((bg-primary "#222222" "unspecified" "unspecified")
 (bg-secondary "#27282c" "unspecified" "unspecified")
 (bg-hl "#2f2f2f" "unspecified" "blue")
 (fg-primary "#a6a8a9" "unspecified" "white")
 (fg-secondary "#cccccc" "unspecified" "gray")
 (fg-muted "#707070" "unspecified" "gray")
 (accent-blue "#69aaff" "#5fafff" "blue")
 (accent-cyan "#00bbb7" "#00afaf" "cyan")
 (accent-green "#61bd09" "#5faf00" "green")
 (accent-magenta "#ff77cf" "#ff87d7" "magenta")
 (accent-orange "#fd892c" "#ff8700" "red")
 (accent-purple "#a89bff" "#afafff" "magenta")
 (accent-red "#f88785" "#ff8787" "red")
 (accent-warning "#d2a022" "#d7af00" "red")
 (accent-yellow "#b8aa07" "#afaf00" "yellow")
 (bg-diff-added "#152615" "#005f00" "green")
 (bg-diff-removed "#301d1e" "#5f0000" "red")
 (bg-diff-header "#092147" "blue" "blue")
 (border "#404047" "#444444" "brightblack")
 (cursor "#4455bb" "#5f5faf" "blue")
 (comment "#bda38e" "#afaf87" "yellow"))
)

      (faces '((default :foreground fg-primary :background bg-primary)
 (cursor :background cursor)
 (region :background bg-hl :extend t :distant-foreground fg-primary)
 (highlight :background bg-hl :weight bold)
 (error :foreground accent-red :weight bold)
 (warning :foreground accent-warning :weight bold :slant o)
 (success :foreground accent-green :weight bold)
 (mode-line :foreground fg-secondary :background bg-secondary)
 (mode-line-inactive :foreground fg-muted :background bg-primary
                     :inherit mode-line)
 (doom-modeline-project-name :foreground fg-primary :inherit
                             (doom-modeline italic))
 (minibuffer-prompt :foreground accent-cyan :weight bold)
 (fringe :background bg-primary :foreground fg-muted)
 (vertical-border :foreground border)
 (window-divider :foreground border)
 (tab-bar :background bg-primary :height 0.95)
 (tab-bar-tab :background bg-secondary :weight bold)
 (tab-bar-tab-inactive :background bg-primary)
 (tooltip :inherit vertico-current)
 (custom-button :inherit highlight :box
                (:line-width 2 :style released-button))
 (custom-button-mouse :inherit custom-button-mouse)
 (custom-button-pressed :inherit custom-buttom :box
                        (:line-width 2 :style pressed-button))
 (widget-field :underline t)
 (font-lock-builtin-face :foreground accent-magenta)
 (font-lock-comment-delimiter-face :inherit font-lock-comment-face)
 (font-lock-comment-face :foreground comment :slant italic)
 (font-lock-constant-face :foreground accent-blue)
 (font-lock-doc-face :foreground accent-blue)
 (font-lock-doc-markup-face :foreground accent-purple)
 (font-lock-function-name-face :foreground accent-green :weight bold)
 (font-lock-keyword-face :foreground accent-magenta)
 (font-lock-negation-char-face :foreground accent-orange :weight bold)
 (font-lock-preprocessor-face :inherit font-lock-builtin-face)
 (font-lock-string-face :foreground accent-purple)
 (font-lock-type-face :foreground accent-cyan)
 (font-lock-variable-name-face :foreground accent-yellow)
 (font-lock-warning-face :inherit warning)
 (tree-sitter-hl-face:attribute :inherit font-lock-constant-face)
 (tree-sitter-hl-face:comment :inherit font-lock-comment-face)
 (tree-sitter-hl-face:constant :inherit font-lock-constant-face)
 (tree-sitter-hl-face:constant.builtin :inherit font-lock-builtin-face)
 (tree-sitter-hl-face:constructor :foreground accent-cyan)
 (tree-sitter-hl-face:function :inherit font-lock-function-name-face)
 (tree-sitter-hl-face:function.builtin :inherit font-lock-builtin-face)
 (tree-sitter-hl-face:function.call :inherit
                                    font-lock-function-name-face
                                    :weight normal)
 (tree-sitter-hl-face:function.macro :inherit
                                     font-lock-preprocessor-face)
 (tree-sitter-hl-face:keyword :inherit font-lock-keyword-face)
 (tree-sitter-hl-face:punctuation :foreground fg-secondary)
 (tree-sitter-hl-face:punctuation.bracket :foreground fg-primary)
 (tree-sitter-hl-face:punctuation.delimiter :foreground fg-primary)
 (tree-sitter-hl-face:punctuation.special :foreground accent-magenta)
 (tree-sitter-hl-face:string :inherit font-lock-string-face)
 (tree-sitter-hl-face:string.special :foreground accent-red)
 (tree-sitter-hl-face:tag :inherit font-lock-keyword-face)
 (tree-sitter-hl-face:type :inherit font-lock-type-face)
 (tree-sitter-hl-face:type.builtin :inherit font-lock-type-face
                                   :weight bold)
 (tree-sitter-hl-face:type.parameter :foreground accent-cyan)
 (tree-sitter-hl-face:variable :inherit font-lock-variable-name-face)
 (tree-sitter-hl-face:variable.builtin :foreground accent-magenta)
 (tree-sitter-hl-face:variable.parameter :inherit
                                         font-lock-variable-name-face
                                         :weight normal)
 (shadow :foreground fg-muted)
 (match :foreground "white" :background bg-hl :weight bold :slant i
        :box (:line-width 1 :color border) :underline
        (:style line :position -5))
 (isearch :inherit match)
 (isearch-fail :background "red" :foreground "white" :inherit match)
 (lazy-highlight :foreground fg-primary :inherit match)
 (vertico-current :foreground "white" :background bg-hl :weight bold
                  :slant o :extend t)
 (corfu-default :background bg-secondary)
 (corfu-current :inherit vertico-current)
 (corfu-border :background border) (corfu-bar :background fg-muted)
 (corfu-annotations :foreground fg-muted :slant italic)
 (orderless-match-face-0 :foreground accent-cyan :weight bold)
 (orderless-match-face-1 :foreground accent-green :weight bold)
 (orderless-match-face-2 :foreground accent-magenta :weight bold)
 (orderless-match-face-3 :foreground accent-yellow :weight bold)
 (marginalia-documentation :inherit font-lock-doc-face)
 (outline-1 :foreground accent-magenta :weight bold :height 200)
 (outline-2 :foreground accent-green :weight bold :height 180)
 (outline-3 :foreground accent-cyan :weight bold :height 160)
 (outline-4 :foreground accent-red :weight bold :height 140)
 (outline-5 :foreground accent-purple :weight bold :height 130)
 (outline-6 :foreground accent-yellow :weight bold :height 120)
 (outline-7 :foreground comment :weight bold :height 110)
 (outline-8 :foreground accent-orange :weight bold :height 100)
 (org-block :background bg-secondary)
 (org-block-begin-line :foreground fg-muted :background bg-secondary
                       :extend t)
 (org-block-end-line :inherit org-block-begin-line)
 (org-code :foreground accent-warning :background bg-secondary)
 (org-verbatim :inherit org-code) (org-date :foreground accent-cyan)
 (org-drawer :foreground fg-muted) (org-ellipsis :foreground fg-muted)
 (dired-rainbow-directory-face :foreground accent-blue)
 (dired-rainbow-html-face :foreground accent-red)
 (dired-rainbow-xml-face :foreground accent-yellow)
 (dired-rainbow-document-face :foreground accent-purple)
 (dired-rainbow-markdown-face :foreground accent-magenta)
 (dired-rainbow-database-face :foreground accent-blue)
 (dired-rainbow-media-face :foreground accent-purple)
 (dired-rainbow-image-face :foreground accent-purple)
 (dired-rainbow-log-face :foreground accent-warning)
 (dired-rainbow-shell-face :foreground accent-green)
 (dired-rainbow-interpreted-face :foreground accent-green)
 (dired-rainbow-compiled-face :foreground accent-green)
 (dired-rainbow-executable-face :foreground accent-green)
 (dired-rainbow-compressed-face :foreground accent-red)
 (dired-rainbow-packaged-face :foreground accent-purple)
 (dired-rainbow-encrypted-face :foreground accent-yellow)
 (dired-rainbow-fonts-face :foreground accent-blue)
 (dired-rainbow-partition-face :foreground accent-red)
 (dired-rainbow-vc-face :foreground accent-blue)
 (dired-rainbow-executable-unix-face :foreground accent-green)
 (all-the-icons-dired-dir-face :foreground accent-blue)
 (diredfl-compressed-file-name :foreground accent-red)
 (diredfl-compressed-file-suffix :inherit diredfl-compressed-file-name)
 (diredfl-mode-set-explicitly :inherit default)
 (diredfl-number :foreground accent-cyan)
 (diredfl-no-priv :inherit diredfl-mode-set-explicitly)
 (diredfl-dir-name :foreground accent-blue)
 (diredfl-dir-priv :inherit diredfl-dir-name)
 (diredfl-date-time :foreground accent-blue)
 (diredfl-executable-tag :foreground accent-green)
 (diredfl-exec-priv :inherit diredfl-executable-tag)
 (diredfl-file-name :foreground fg-primary)
 (diredfl-symlink :foreground accent-cyan)
 (diredfl-link-priv :inherit diredfl-symlink)
 (diredfl-rare-priv :foreground accent-magenta)
 (diredfl-read-priv :foreground accent-yellow)
 (diredfl-other-priv :foreground accent-warning)
 (diredfl-write-priv :foreground accent-red)
 (diredfl-dir-heading :inherit font-lock-comment-face :background
                      bg-primary)
 (diredfl-file-suffix :foreground accent-orange)
 (diredfl-autofile-name :foreground accent-yellow)
 (diredfl-tagged-autofile-name :inherit accent-red)
 (diredfl-flag-mark-line :background cursor)
 (diredfl-flag-mark :inherit diredfl-flag-mark-line)
 (diredfl-ignored-file-name :foreground fg-muted :slant i)
 (diredfl-deletion-file-name :background accent-red :foreground
                             bg-primary)
 (diredfl-deletion :inherit diredfl-deletion-file-name)
 (dired-efap-face :foreground "white" :box
                  (:line-width 2 :color border :style pressed-button))
 (diff-added :background bg-diff-added :foreground accent-green
             :extend t)
 (diff-removed :background bg-diff-removed :foreground accent-red
               :extend t)
 (diff-refine-added :background accent-green :foreground bg-primary
                    :weight bold)
 (diff-refine-removed :background accent-red :foreground bg-primary
                      :weight bold)
 (diff-header :background bg-diff-header)
 (diff-file-header :inherit diff-header)
 (diff-indicator-added :inherit diff-added :foreground accent-green)
 (diff-indicator-removed :inherit diff-removed :foreground accent-red)
 (magit-section-highlight :background bg-hl :extend t)
 (magit-diff-context-highlight :background bg-hl :extend t)
 (magit-diff-hunk-heading :background border :extend t)
 (magit-diff-added :background bg-diff-added :extend t)
 (magit-diff-removed :background bg-diff-removed :extend t)
 (magit-diff-added-highlight :inherit magit-diff-added)
 (magit-diff-removed-highlight :inherit magit-diff-removed)
 (magit-section-heading :foreground accent-yellow :weight bold)
 (magit-branch-remote :foreground accent-green :slant i)
 (magit-branch-local :foreground accent-cyan)
 (ediff-current-diff-A :inherit diff-removed)
 (ediff-fine-diff-A :inherit diff-refine-removed)
 (ediff-current-diff-B :inherit diff-added)
 (ediff-fine-diff-B :inherit diff-refine-added)
 (ediff-current-diff-C :background accent-green)
 (ediff-fine-diff-C :background accent-cyan)
 (ediff-odd-diff-A :inherit diff-header)
 (ediff-even-diff-A :inherit diff-header)
 (ediff-odd-diff-B :inherit diff-header)
 (ediff-even-diff-B :inherit diff-header)
 (ediff-odd-diff-C :inherit diff-header)
 (ediff-even-diff-C :inherit diff-header)
 (web-mode-html-tag-face :foreground accent-magenta :weight bold)
 (web-mode-html-attr-name-face :foreground accent-purple)
 (web-mode-html-attr-value-face :foreground accent-green)
 (web-mode-css-property-name-face :inherit font-lock-constant-face)
 (web-mode-css-color-face :background accent-blue :foreground
                          bg-primary)
 (web-mode-keyword-face :inherit font-lock-keyword-face)
 (web-mode-doctype-face :inherit shadow)
 (web-mode-string-face :foreground accent-yellow)
 (link :foreground fg-primary :underline t :weight bold)
 (link-visited :foreground accent-purple :underline t)
 (button :foreground "white" :weight semi-bold :underline
         (:color bg-hl :style double-line))
 (trailing-whitespace :background accent-red)
 (whitespace-tab :background "#330022")
 (ansi-color-black :foreground bg-secondary)
 (ansi-color-red :foreground accent-red)
 (ansi-color-green :foreground accent-green)
 (ansi-color-yellow :foreground accent-yellow)
 (ansi-color-blue :foreground accent-blue)
 (ansi-color-magenta :foreground accent-magenta)
 (ansi-color-cyan :foreground accent-cyan)
 (ansi-color-white :foreground fg-primary)
 (ansi-color-bright-black :foreground fg-muted)
 (ansi-color-bright-red :foreground accent-red :weight bold)
 (ansi-color-bright-green :foreground accent-green :weight bold)
 (ansi-color-bright-yellow :foreground accent-yellow :weight bold)
 (ansi-color-bright-blue :foreground accent-blue :weight bold)
 (ansi-color-bright-magenta :foreground accent-magenta :weight bold)
 (ansi-color-bright-cyan :foreground accent-cyan :weight bold)
 (ansi-color-bright-white :foreground fg-primary :weight bold)
 (vterm-color-black :inherit ansi-color-black)
 (vterm-color-red :inherit ansi-color-red)
 (vterm-color-green :inherit ansi-color-green)
 (vterm-color-yellow :inherit ansi-color-yellow)
 (vterm-color-blue :inherit ansi-color-blue)
 (vterm-color-magenta :inherit ansi-color-magenta)
 (vterm-color-cyan :inherit ansi-color-cyan)
 (vterm-color-white :inherit ansi-color-white)
 (aw-leading-char-face :foreground accent-red :height 250)
 (elpaca-finished :foreground accent-green :weight bold)
 (eldoc-box-border :background accent-purple)
 (lsp-face-highlight-read :weight extra-bold :underline t)
 (lsp-face-highlight-write :inherit lsp-face-highlight-read :underline
                           nil)
 (sh-heredoc :inherit font-lock-doc-face)
 (sh-quoted-exec :foreground accent-red)
 (ansible-task-label-face :foreground accent-green)
 (flycheck-error :underline (:style wave :color accent-magenta))
 (show-paren-match :foreground "white" :weight extra-bold)
 (fill-column-indicator :foreground border)
 (highlight-indent-guides-even-face :foreground border :background
                                    border)
 (highlight-indent-guides-odd-face :foreground border :background
                                   border)
 (highlight-indent-guides-top-odd-face :foreground border :background
                                       border)
 (highlight-indent-guides-top-even-face :foreground border :background
                                        border)
 (highlight-indent-guides-character-face :foreground border
                                         :background border)
 (highlight-indent-guides-stack-odd-face :foreground border
                                         :background border)
 (eros-result-overlay-face :foreground fg-muted :box
                           (:line-width -1 :color border)))
))

  (letrec
      ((resolve
        (lambda (attrs idx)
          (let (result rest)
            (setq rest attrs)
            (while rest
              (let ((key (pop rest))
                    (val (pop rest)))
                (push key result)
                (cond
                 ;; :inherit must never be color-substituted
                 ((eq key :inherit)
                  (push val result))
                 ;; Palette symbol → actual color at index IDX
                 ((and (symbolp val) (assq val colors))
                  (push (nth idx (assq val colors)) result))
                 ;; Nested plist (only for :box, :underline, etc.)
                 ((and (memq key '(:box :underline :overline :strike-through))
                       (listp val))
                  (push (funcall resolve val idx) result))
                 ;; Anything else (literals, keywords, nil, t) → keep
                 (t
                  (push val result)))))
            (nreverse result)))))

    (apply #'custom-theme-set-faces 'neron-dark
           (mapcar (lambda (face-spec)
                     (let ((face  (car face-spec))
                           (attrs (cdr face-spec)))
                       `(,face
                         ((((min-colors 16777216)) ; graphical / 24-bit
                           ,(funcall resolve attrs 1))
                          (((min-colors 256))      ; 256-color terminal
                           ,(funcall resolve attrs 2))
                          (t                       ; tty fallback
                           ,(funcall resolve attrs 3))))))
                   faces))))
;;;###autoload
(when (and (boundp 'custom-theme-load-path) load-file-name)
  (add-to-list 'custom-theme-load-path
               (file-name-directory load-file-name)))

(provide-theme 'neron-dark)
;;; neron-dark-theme.el ends here
