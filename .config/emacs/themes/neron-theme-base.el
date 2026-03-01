;;; neron-theme-base.el --- Neron Theme Base Framework -*- lexical-binding: t; -*-

;; Author: 11xx
;; Version: 2026-02-28
;; Keywords: faces theme

;;; Commentary:

;; Shared infrastructure for Neron themes.
;; Each theme file supplies its own color palette and optional face overrides.
;; All common face definitions live here as the single source of truth.

;;; Code:

;;;###autoload
(when (boundp 'custom-theme-load-path)
  (add-to-list 'custom-theme-load-path
               (file-name-directory (or load-file-name buffer-file-name))))


(defun neron--create-theme (variant colors &optional face-overrides)
  "Create a Neron theme for VARIANT (symbol: dark or light).

COLORS is an alist of (NAME HEX-24BIT HEX-256 TTY-COLOR).
FACE-OVERRIDES is an optional alist of (FACE-NAME PROP VAL ...) entries
that replace specific faces from the base definition for this variant."
  (let* ((theme-name (intern (format "neron-%s" variant)))
         (group-name (intern (format "neron-%s" variant)))
         (prefix-str (format "neron-%s-" variant)))

    ;; custom-declare-theme is the function underlying the deftheme macro
    (custom-declare-theme theme-name nil
      (format "Neron %s theme with neon-pastel accents and lower contrast."
              (capitalize (symbol-name variant))))

    ;; custom-declare-group is the function underlying defgroup
    (custom-declare-group group-name nil
      (format "Neron %s theme options." (capitalize (symbol-name variant)))
      :group 'faces
      :prefix prefix-str)

    ;; custom-declare-variable is the function underlying defcustom;
    ;; unlike the macro, it takes the default as an evaluated value directly
    (custom-declare-variable
     (intern (concat prefix-str "enlarge-headings")) t
     "Use scaled font sizes for headings."
     :type 'boolean
     :group group-name)

    (custom-declare-variable
     (intern (concat prefix-str "heading-height-ratio")) 1.2
     "Height multiplier for heading faces (1.0 = normal)."
     :type 'float
     :group group-name)

    (custom-declare-variable
     (intern (concat prefix-str "reduce-minibuffer-decoration")) nil
     "Minimize styling in minibuffer and mode-line."
     :type 'boolean
     :group group-name)

    (let ((all-faces (neron--merge-faces (neron--get-base-faces) face-overrides)))
      (apply #'custom-theme-set-faces theme-name
             (neron--build-face-specs all-faces colors)))

    ;; provide-theme is a plain function, no eval needed
    (provide-theme theme-name)))


(defun neron--substitute-colors (face-attrs color-alist color-index)
  "Substitute color symbols in FACE-ATTRS plist using COLOR-ALIST at COLOR-INDEX.
COLOR-INDEX: 1 = primary (24-bit), 2 = 256-color, 3 = tty.
Recursively handles nested plists such as :box or :underline values."
  (let ((result nil)
        (attrs face-attrs))
    (while attrs
      (let ((key (pop attrs))
            (val (pop attrs)))
        (push key result)
        (cond
         ;; Palette symbol → substitute resolved color
         ((and (symbolp val) (assoc val color-alist))
          (push (nth color-index (assoc val color-alist)) result))
         ;; Nested plist, e.g. (:line-width 1 :color border) → recurse
         ((listp val)
          (push (neron--substitute-colors val color-alist color-index) result))
         ;; Literal string, number, keyword, t, nil, unspecified → keep
         (t
          (push val result)))))
    (nreverse result)))


(defun neron--merge-faces (base-faces overrides)
  "Return BASE-FACES alist with OVERRIDES entries replacing matching faces.
Faces in OVERRIDES that are absent from BASE-FACES are appended."
  (if (not overrides)
      base-faces
    (let ((result (copy-alist base-faces)))
      (dolist (override overrides)
        ;; setf on alist-get: modifies cdr in-place when key exists,
        ;; prepends a new entry when it doesn't
        (setf (alist-get (car override) result)
              (cdr override)))
      result)))


(defun neron--build-face-specs (faces color-alist)
  "Build the argument list for `custom-theme-set-faces' from FACES and COLOR-ALIST.
Each entry covers three display conditions: 24-bit, 256-color, and tty."
  (mapcar
   (lambda (face-spec)
     (let ((face-name  (car face-spec))
           (face-attrs (cdr face-spec)))
       `(,face-name
         ((((min-colors 16777216))        ; graphical / 24-bit color
           ,(neron--substitute-colors face-attrs color-alist 1))
          (((min-colors 256))             ; 256-color terminal
           ,(neron--substitute-colors face-attrs color-alist 2))
          (t                              ; tty fallback
           ,(neron--substitute-colors face-attrs color-alist 3))))))
   faces))


(defun neron--get-base-faces ()
  "Return alist of all base face specifications.
This is the single source of truth for face definitions shared across variants.
Theme files override only the faces that differ between dark and light."
  '(
    (default :foreground fg-primary :background bg-primary)
    (cursor :background cursor)
    (region :background bg-hl :extend t :distant-foreground fg-primary)
    (highlight :background bg-hl :weight bold)
    (error :foreground accent-red :weight bold)
    (warning :foreground accent-warning :weight bold :slant o)
    (success :foreground accent-green :weight bold)

    ;; UI
    (mode-line
     :foreground fg-secondary
     :background bg-secondary)
    (mode-line-inactive
     :foreground fg-muted
     :background bg-primary
     :inherit mode-line)

    (doom-modeline-project-name :foreground fg-primary :inherit (doom-modeline italic))

    (minibuffer-prompt :foreground accent-cyan :weight bold)
    (fringe :background bg-primary :foreground fg-muted)
    (vertical-border :foreground border)
    (window-divider :foreground border)
    (tab-bar :background bg-primary :height 0.95)
    (tab-bar-tab :background bg-secondary :weight bold)
    (tab-bar-tab-inactive :background bg-primary)
    (tooltip :inherit vertico-current)

    ;; Custom menu
    (custom-button :inherit highlight :box (:line-width 2 :style released-button))
    (custom-button-mouse :inherit custom-button-mouse)
    (custom-button-pressed :inherit custom-buttom :box (:line-width 2 :style pressed-button))
    (widget-field :underline t)

    ;; SYNTAX HIGHLIGHTING
    ;; Font-lock hierarchy provides base syntax coloring
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
    (tree-sitter-hl-face:function.call :inherit font-lock-function-name-face :weight normal)
    (tree-sitter-hl-face:function.macro :inherit font-lock-preprocessor-face)
    (tree-sitter-hl-face:keyword :inherit font-lock-keyword-face)
    (tree-sitter-hl-face:punctuation :foreground fg-secondary)
    (tree-sitter-hl-face:punctuation.bracket :foreground fg-primary)
    (tree-sitter-hl-face:punctuation.delimiter :foreground fg-primary)
    (tree-sitter-hl-face:punctuation.special :foreground accent-magenta)
    (tree-sitter-hl-face:string :inherit font-lock-string-face)
    (tree-sitter-hl-face:string.special :foreground accent-red)
    (tree-sitter-hl-face:tag :inherit font-lock-keyword-face)
    (tree-sitter-hl-face:type :inherit font-lock-type-face)
    (tree-sitter-hl-face:type.builtin :inherit font-lock-type-face :weight bold)
    (tree-sitter-hl-face:type.parameter :foreground accent-cyan)
    (tree-sitter-hl-face:variable :inherit font-lock-variable-name-face)
    (tree-sitter-hl-face:variable.builtin :foreground accent-magenta)
    (tree-sitter-hl-face:variable.parameter :inherit font-lock-variable-name-face :weight normal)

    ;; other typography
    (shadow :foreground fg-muted)

    ;; SEARCH & SELECTION
    (match :foreground "white" :background bg-hl
           :weight bold :slant i
           :box (:line-width 1 :color border)
           :underline (:style line :position -5))
    (isearch :inherit match)
    (isearch-fail :background "red" :foreground "white" :inherit match)
    (lazy-highlight :foreground fg-primary :inherit match)

    ;; COMPLETION & NAVIGATION
    (vertico-current
     :background bg-hl
     :foreground "white"
     :weight bold
     :slant o
     :extend t)

    (corfu-default :background bg-secondary)
    (corfu-current :inherit vertico-current)
    (corfu-border :background border)
    (corfu-bar :background fg-muted)
    (corfu-annotations :foreground fg-muted :slant italic)

    ;; Orderless match coloring
    (orderless-match-face-0 :foreground accent-cyan :weight bold)
    (orderless-match-face-1 :foreground accent-green :weight bold)
    (orderless-match-face-2 :foreground accent-magenta :weight bold)
    (orderless-match-face-3 :foreground accent-yellow :weight bold)

    (marginalia-documentation :inherit font-lock-doc-face)

    ;; ORG-MODE
    (outline-1 :foreground accent-magenta :weight bold :height 200)
    (outline-2 :foreground accent-green   :weight bold :height 180)
    (outline-3 :foreground accent-cyan    :weight bold :height 160)
    (outline-4 :foreground accent-red     :weight bold :height 140)
    (outline-5 :foreground accent-purple  :weight bold :height 130)
    (outline-6 :foreground accent-yellow  :weight bold :height 120)
    (outline-7 :foreground comment        :weight bold :height 110)
    (outline-8 :foreground accent-orange  :weight bold :height 100)

    (org-block :background bg-secondary)
    (org-block-begin-line :foreground fg-muted :background bg-secondary :extend t)
    (org-block-end-line :inherit org-block-begin-line)
    (org-code :foreground accent-warning :background bg-secondary)
    (org-verbatim :inherit org-code)
    (org-date :foreground accent-cyan)
    (org-drawer :foreground fg-muted)
    (org-ellipsis :foreground fg-muted)

    ;; DIRED
    (dired-rainbow-directory-face        :foreground accent-blue)
    (dired-rainbow-html-face             :foreground accent-red)
    (dired-rainbow-xml-face              :foreground accent-yellow)
    (dired-rainbow-document-face         :foreground accent-purple)
    (dired-rainbow-markdown-face         :foreground accent-magenta)
    (dired-rainbow-database-face         :foreground accent-blue)
    (dired-rainbow-media-face            :foreground accent-purple)
    (dired-rainbow-image-face            :foreground accent-purple)
    (dired-rainbow-log-face              :foreground accent-warning)
    (dired-rainbow-shell-face            :foreground accent-green)
    (dired-rainbow-interpreted-face      :foreground accent-green)
    (dired-rainbow-compiled-face         :foreground accent-green)
    (dired-rainbow-executable-face       :foreground accent-green)
    (dired-rainbow-compressed-face       :foreground accent-red)
    (dired-rainbow-packaged-face         :foreground accent-purple)
    (dired-rainbow-encrypted-face        :foreground accent-yellow)
    (dired-rainbow-fonts-face            :foreground accent-blue)
    (dired-rainbow-partition-face        :foreground accent-red)
    (dired-rainbow-vc-face               :foreground accent-blue)
    (dired-rainbow-executable-unix-face  :foreground accent-green)

    (all-the-icons-dired-dir-face :foreground accent-blue)

    (diredfl-compressed-file-name :foreground accent-red)                        ;; *Face used for compressed file names.
    (diredfl-compressed-file-suffix :inherit diredfl-compressed-file-name)       ;; *Face used for compressed file suffixes in Dired buffers. This means the ‘.’ plus the file extension.  Example: ‘.zip’.
    (diredfl-mode-set-explicitly :inherit default)                               ;; Basic default face.
    (diredfl-number :foreground accent-cyan)                                     ;; *Face used for numerical fields in Dired buffers. In particular, inode number, number of hard links, and file size.
    (diredfl-no-priv :inherit diredfl-mode-set-explicitly)                       ;; *Face used for no privilege indicator (-) in Dired buffers.
    (diredfl-dir-name :foreground accent-blue)                                   ;; *Face used for directory names.
    (diredfl-dir-priv :inherit diredfl-dir-name)                                 ;; *Face used for directory privilege indicator (d) in Dired buffers.
    (diredfl-date-time :foreground accent-blue)                                  ;; *Face used for date and time in Dired buffers.
    (diredfl-executable-tag :foreground accent-green)                            ;; *Face used for executable tag (*) on file names in Dired buffers.
    (diredfl-exec-priv :inherit diredfl-executable-tag)                          ;; *Face used for execute privilege indicator (x) in Dired buffers.
    (diredfl-file-name :foreground fg-primary)                                   ;; *Face used for file names (without suffixes) in Dired buffers. This means the base name.  It does not include the ‘.’.
    (diredfl-symlink :foreground accent-cyan)                                    ;; *Face used for symbolic links in Dired buffers.
    (diredfl-link-priv :inherit diredfl-symlink)                                 ;; *Face used for link privilege indicator (l) in Dired buffers.
    (diredfl-rare-priv :foreground accent-magenta)                               ;; *Face used for rare privilege indicators (b,c,s,m,p,S) in Dired buffers.
    (diredfl-read-priv :foreground accent-yellow)                                ;; *Face used for read privilege indicator (w) in Dired buffers.
    (diredfl-other-priv :foreground accent-warning)                              ;; *Face used for l,s,S,t,T privilege indicators in Dired buffers.
    (diredfl-write-priv :foreground accent-red)                                  ;; *Face used for write privilege indicator (w) in Dired buffers.
    (diredfl-dir-heading :inherit font-lock-comment-face :background bg-primary) ;; *Face used for directory headings in Dired buffers.
    (diredfl-file-suffix undefined)                                              ;; *Face used for file suffixes in Dired buffers. This means the ‘.’ plus the file extension.  Example: ‘.elc’.
    (diredfl-autofile-name :foreground accent-yellow)                            ;; *Face used in Dired for names of files that are autofile bookmarks.
    (diredfl-tagged-autofile-name :inherit accent-red)                           ;; *Face used in Dired for names of files that are autofile bookmarks.
    (diredfl-flag-mark-line :background cursor)                                  ;; *Face used for flagged and marked lines in Dired buffers.
    (diredfl-flag-mark :inherit diredfl-flag-mark-line)                          ;; *Face used for flags and marks (except D) in Dired buffers.
    (diredfl-ignored-file-name :foreground fg-muted :slant i)                    ;; *Face used for ignored file names  in Dired buffers.
    (diredfl-deletion-file-name :background accent-red :foreground bg-primary)   ;; *Face used for names of deleted files in Dired buffers.
    (diredfl-deletion :inherit diredfl-deletion-file-name)                       ;; *Face used for deletion flags (D) in Dired buffers.

    (dired-efap-face :foreground "white" :box (:line-width 2 :color border :style pressed-button))

    ;; VERSION CONTROL
    (diff-added :background bg-diff-added :foreground accent-green :extend t)
    (diff-removed :background bg-diff-removed :foreground accent-red :extend t)
    (diff-refine-added :background accent-green :foreground bg-primary :weight bold)
    (diff-refine-removed :background accent-red :foreground bg-primary :weight bold)
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

    ;; WEB MODE
    (web-mode-html-tag-face :foreground accent-magenta :weight bold)
    (web-mode-html-attr-name-face :foreground accent-purple)
    (web-mode-html-attr-value-face :foreground accent-green)
    (web-mode-css-property-name-face :inherit font-lock-constant-face)
    (web-mode-css-color-face :background accent-blue :foreground bg-primary)
    (web-mode-keyword-face :inherit font-lock-keyword-face)
    (web-mode-doctype-face :inherit shadow)
    (web-mode-string-face :foreground accent-yellow) ; :inherit font-lock-string-face

    ;; MISC
    (link :foreground fg-primary :underline t :weight bold)
    (link-visited :foreground accent-purple :underline t)
    (button :foreground "white" :weight semi-bold :underline (:color bg-hl :style double-line))
    (trailing-whitespace :background accent-red)
    (whitespace-tab :background "#330022")

    ;;; ANSI TERMINAL
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

    ;; vterm integration
    (vterm-color-black :inherit ansi-color-black)
    (vterm-color-red :inherit ansi-color-red)
    (vterm-color-green :inherit ansi-color-green)
    (vterm-color-yellow :inherit ansi-color-yellow)
    (vterm-color-blue :inherit ansi-color-blue)
    (vterm-color-magenta :inherit ansi-color-magenta)
    (vterm-color-cyan :inherit ansi-color-cyan)
    (vterm-color-white :inherit ansi-color-white)

    ;; PACKAGE-SPECIFIC
    (aw-leading-char-face :foreground accent-red :height 250)
    (elpaca-finished :foreground accent-green :weight bold)
    (eldoc-box-border :background accent-purple)
    (lsp-face-highlight-read :weight extra-bold :underline t)
    (lsp-face-highlight-write :inherit lsp-face-highlight-read :underline nil)
    (sh-heredoc :inherit font-lock-doc-face)
    (sh-quoted-exec :foreground accent-red)
    (ansible-task-label-face :foreground accent-green)
    (flycheck-error :underline (:style wave :color accent-magenta))
    (show-paren-match :foreground "white" :weight extra-bold)
    (fill-column-indicator :foreground border)
    (highlight-indent-guides-even-face :foreground border :background border)
    (highlight-indent-guides-odd-face :foreground border :background border)
    (highlight-indent-guides-top-odd-face :foreground border :background border)
    (highlight-indent-guides-top-even-face :foreground border :background border)
    (highlight-indent-guides-character-face :foreground border :background border)
    (highlight-indent-guides-stack-odd-face :foreground border :background border)
    (eros-result-overlay-face :foreground fg-muted :box (:line-width -1 :color border))
    ))


(provide 'neron-theme-base)
;;; neron-theme-base.el ends here
