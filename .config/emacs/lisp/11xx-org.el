;; -*- lexical-binding: t; -*-
(require '11xx-org-functions)
;; (setup org
;;   ;; Disable angle bracket syntax highlighting/matching
;;   (:hook (lambda()
;;            (modify-syntax-entry ?< "." org-mode-syntax-table)
;;            (modify-syntax-entry ?> "." org-mode-syntax-table))))

(setup (:elpaca org-contrib)
  (:load-after org)
  (require 'org-eldoc))
;; `org-eldoc' shows the inherited code block properties.

(setup org
  (:with-map org-mode-map
    (:bind
     "C-c C-;" org-babel-repeat-previous-src-block
     ;; "C-c C-'" org-babel-repeat-previous-src-block-reverse ;; use `org-babel-demarcate-block' instead #DONE-TO-SEND-CEMETARY
     "C-M-p" org-previous-visible-heading ; was `backward-list'
     "C-M-n" org-next-visible-heading ; was `forward-list'
     "C-c o t l" org-toggle-link-display
     ;; Meta indentation ; `S' for Shift not working for some reason
     "M-F" org-metaright
     "M-B" org-metaleft
     "M-P" org-metaup
     "M-N" org-metadown
     ;; Cursor
     ;; "C-M-d" ; was down-list
     "C-M-d" backward-delete-char ; was down-list
     "M-D" backward-kill-word
     ;; "M-h"   backward-delete-char ; was `org-mark-element'
     ;; "M-H"   backward-kill-word ; was `org-mark-element' in org map
     "C-c o p" org-kill-full-outline-path))


  ;; [[https://orgmode.org/manual/Activation.html][src]]
  ;; Enable Org-mode commands to be available anywhere.
  (:global "C-c o l" org-store-link
           "C-c o a" org-agenda
           "C-c o c" org-capture)

  ;; Move this to file local
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((haskell t)
             ;; (async   . t) ; from ob-async
             (shell   . t)
             (C       . t))))
  ;; Disable angle bracket syntax highlighting/matching
  (add-hook 'org-mode-hook
            (lambda()
              (modify-syntax-entry ?< "." org-mode-syntax-table)
              (modify-syntax-entry ?> "." org-mode-syntax-table)))
  ;; Additional templates for `org-insert-structure-template'
  (dolist (begin
           '(;; code
             ("sh" . "src shell")
             ("el" . "src emacs-lisp")
             ("py" . "src python")
             ("js" . "src javascript")
             ("css" . "src css")
             ("cc" . "src conf")
             ("hs" . "src haskell")
             ("sd" . "src systemd")
             ("y" . "src yaml")
             ;; org special
             ("sa" . "seealso")
             ))
    (add-to-list 'org-structure-template-alist begin))

  (setopt
 ;;; Org mode version 9.5:
   ;; ~org-adapt-indentation~ now defaults to ~nil~
   org-adapt-indentation nil ;; testing nil [2022-03-31 Thu 07:34:31]
   ;;; UI
   org-ellipsis " ▾"
   org-hide-emphasis-markers t
   ;;; Properties
   ;; org-use-property-inheritance t ; Apparently slows down searches when on.
   ;;; Default header-args for evaluation
   org-babel-default-header-args:emacs-lisp '((:lexical . yes))
   org-image-actual-width nil
   ;; Edit src blocks in the current window instead of split
   org-src-window-setup 'current-window)

;; Visual Fill Column
;; [[https://github.com/daviwil/emacs-from-scratch/blob/master/Emacs.org#center-org-buffers][Emacs From Scratch/Emacs.org#Center Org Buffers]].
(setup (:elpaca visual-fill-column)
  (:load-after org)
  (setopt visual-fill-column-width 130 ; use with `display-fill-column-indicator-mode'
          visual-fill-column-center-text t)
  (:hook-into org-mode))

(setup (:elpaca org-bulletproof)
  (:load-after org)
  (:hook-into org-mode))
(defun f/org-export-dispatch-disable-whitespace-mode (&rest args)
  "Disable `whitespace-mode' for the Org Export Dispatch Buffer."
  (let ((buf (get-buffer "*Org Export Dispatcher*")))
    (when buf
      (with-current-buffer buf
        (setq-local show-trailing-whitespace nil)))))

(advice-add 'org-export--dispatch-action
            :before #'f/org-export-dispatch-disable-whitespace-mode)
(setup (:elpaca org-appear)
  (:load-after org)
  ;; Toggle for links display set in (setup org)
  (setopt org-appear-autolinks 'just-brackets) ; nil is default
  (:hook-into org-mode))
(setup (:elpaca org-modern)
  (setopt org-modern-block-fringe nil)
  (:hook-into org-mode))
(setup (:elpaca org-transclusion)
  (:with-map org-mode-map
    (:bind "C-c o t a" org-transclusion-add
           "C-c o t A" org-transclusion-add-all
           "C-c o t r" org-transclusion-remove)))
(setopt org-export-with-sub-superscripts nil ; interpret "_" and "^" for export.
        org-html-html5-fancy t
        org-export-in-background nil ; export async default: Use 'M-x org-export-stack' to display current processes:
        org-html-validation-link "" ; remove validade xml
        )
(setup (:elpaca htmlize)
  (setopt org-html-head-include-default-style nil
          org-html-htmlize-output-type 'css ; classes
          htmlize-html-charset "UTF-8"
          htmlize-face-overrides '(whitespace-missing-newline-at-eof
                                   (:foreground nil :background nil))))
(setup (:elpaca ox-gfm))
(elpaca (ox-html-stable-ids :host github
                            :repo "jeffkreeftmeijer/ox-html-stable-ids.el")
  (require 'ox-html-stable-ids)
  (setopt org-html-stable-ids t
          org-export-html-stable-ids t)
  (org-html-stable-ids-add))

(elpaca (ox-md-title :host github
                     :repo "jeffkreeftmeijer/ox-md-title.el")
  (require 'ox-md-title))

(defun readme-to-markdown (filename &optional confirm-overwrite)
  "Export the current Org buffer to a Markdown file named FILENAME.
Alternative version using display-buffer-overriding-action for cleaner approach."
  (interactive
   (list (read-file-name "Export markdown to file: "
                         nil nil nil
                         (concat (file-name-sans-extension
                                  (or (buffer-file-name)
                                      (buffer-name)))
                                 ".md"))
         current-prefix-arg))

  (unless (derived-mode-p 'org-mode)
    (user-error "This function only works in Org mode buffers"))

  ;; Check for file existence and confirm if requested
  (when (and confirm-overwrite (file-exists-p filename))
    (unless (yes-or-no-p (format "File %s exists. Overwrite? " filename))
      (user-error "Export cancelled")))

  ;; Save current state
  (let ((original-buffer (current-buffer))
        (make-backup-files nil)
        (original-display-action display-buffer-overriding-action)
        export-buffer)

    ;; Temporarily set display-buffer to not show any buffers
    (setq display-buffer-overriding-action
          '((lambda (buffer alist)
              ;; Return the buffer without displaying it
              buffer)
            . nil))

    (unwind-protect
        (save-window-excursion
          ;; Add the markdown title
          (org-md-title-add)

          ;; Export to buffer (silently)
          (let ((org-md-title t))
            (setq export-buffer (org-gfm-export-as-markdown)))

          ;; Write to file
          (with-current-buffer export-buffer
            (write-region (point-min) (point-max) filename nil 'no-message))

          (message "Exported to %s" filename))

      ;; Restore original display action and cleanup
      (setq display-buffer-overriding-action original-display-action)
      (when (and export-buffer (buffer-live-p export-buffer))
        (kill-buffer export-buffer)))))

(defun readme-org-to-readme-md ()
  (interactive)
  (readme-to-markdown "README.md"))

;;; stable IDs for list-item 

;; (defun f/slugify (s)
;;   "GitHub-style slug: lower-case ASCII, spaces & punctuation → “-”."
;;   (when (and (stringp s) (string-match-p "\\S-" s))
;;     (setq s (downcase s))
;;     (setq s (replace-regexp-in-string "[^[:alnum:]#]+" "-" s)) ; keep “#” for now
;;     (replace-regexp-in-string "[#]" "-" (replace-regexp-in-string "^-\\|-$" "" s))))

;; Add a hash table to track used IDs during export
(defvar v/used-ids-table nil
  "Hash table to track used IDs during export to prevent conflicts.")

;; Add a cache for heading-to-ID mapping to ensure consistency
(defvar v/heading-id-cache nil
  "Hash table to cache heading title to ID mappings for consistency.")

(defun f/slugify (s)
  "GitHub-style slug: preserve more characters, but convert problematic ones."
  (when (and (stringp s) (string-match-p "\\S-" s))
    (setq s (downcase s))
    ;; Convert only truly problematic characters to hyphens
    (setq s (replace-regexp-in-string "[[:space:]#<>\"'&]+" "-" s))
    (replace-regexp-in-string "^-\\|-$" "" s)))

(defun f/extract-first-target (item info)
  "Return the first  object inside ITEM or nil."
  (org-element-map (org-element-contents item) '(target radio-target)
    #'identity info 'first-match))

(defun f/get-heading-path (datum)
  "Get the path to a heading as a list of ancestor headings."
  (let ((path '())
        (current datum))
    (while (setq current (org-element-property :parent current))
      (when (eq (org-element-type current) 'headline)
        (push (org-element-property :raw-value current) path)))
    path))

(defun f/get-heading-cache-key (datum)
  "Generate a cache key for a heading based on its title and position."
  (let* ((title (org-element-property :raw-value datum))
         (path (f/get-heading-path datum)))
    ;; Create a unique key combining title and parent path
    (concat (mapconcat 'identity (reverse path) "/")
            (if path "/" "")
            title)))

(defun f/ensure-unique-id (base-id datum)
  "Ensure BASE-ID is unique, adding disambiguation if needed."
  (unless v/used-ids-table
    (setq v/used-ids-table (make-hash-table :test 'equal)))
  (unless v/heading-id-cache
    (setq v/heading-id-cache (make-hash-table :test 'equal)))

  ;; For headlines, check cache first for consistency
  (when (eq (org-element-type datum) 'headline)
    (let ((cache-key (f/get-heading-cache-key datum)))
      (when-let ((cached-id (gethash cache-key v/heading-id-cache)))
        ;; If we already determined an ID for this heading, use it
        (puthash cached-id t v/used-ids-table)
        ;; Return the cached ID directly instead of using cl-return-from
        (setq base-id cached-id)
        (setq datum nil)))) ; Signal that we should return immediately

  ;; Only proceed if we didn't find a cached result
  (when datum
    (let ((final-id base-id)
          (counter 1)
          (path (f/get-heading-path datum)))

      ;; Check if base-id is already used
      (while (gethash final-id v/used-ids-table)
        ;; Try with parent context first (if available and not too long)
        (when (and path (= counter 1))
          (let ((parent-slug (f/slugify (car (last path)))))
            (when (and parent-slug (< (+ (length parent-slug) (length base-id)) 50))
              (setq final-id (concat parent-slug "-" base-id))
              (setq counter 2)
              (if (not (gethash final-id v/used-ids-table))
                  (setq counter 999))))) ; Exit loop if parent-context works

        ;; If parent context didn't work or we're past first attempt, use numbers
        (when (< counter 999)
          (setq final-id (format "%s-%d" base-id counter))
          (setq counter (1+ counter))))

      ;; Register the final ID
      (puthash final-id t v/used-ids-table)

      ;; Cache the result for headlines to ensure TOC consistency
      (when (eq (org-element-type datum) 'headline)
        (let ((cache-key (f/get-heading-cache-key datum)))
          (puthash cache-key final-id v/heading-id-cache)))

      (setq base-id final-id)))

  base-id)

(defun f/stable-id–around (orig datum info)
  "Supply deterministic IDs for list items, targets, tables, headings with conflict resolution."
  (pcase (org-element-type datum)

    ;; 1. A stand-alone  object --------------------------
    ((or 'target 'radio-target)
     (let* ((raw   (org-element-property :value datum))       ; 
            (clean (and raw (replace-regexp-in-string "[<>]" "" raw))) ; foo
            (base-slug (f/slugify clean)))
       (if base-slug
           (f/ensure-unique-id base-slug datum)
         (funcall orig datum info))))

    ;; 2. A list ITEM that *contains* a  ---------------
    ('item
     (if-let* ((tgt (f/extract-first-target datum info))
               (raw (org-element-property :value tgt))
               (clean (replace-regexp-in-string "[<>]" "" raw))
               (base-slug (f/slugify clean)))
         (f/ensure-unique-id base-slug datum)
       (funcall orig datum info)))

    ;; 3. A table with #+NAME: ------------------------------------
    ('table
     (let* ((name (org-element-property :name datum))
            (base-slug (and name (f/slugify name))))
       (if base-slug
           (f/ensure-unique-id base-slug datum)
         (funcall orig datum info))))

    ;; 4. Headlines -----------------------------------------------
    ('headline
     (let* ((title (org-element-property :raw-value datum))
            (base-slug (f/slugify title)))
       (if base-slug
           (f/ensure-unique-id base-slug datum)
         (funcall orig datum info))))

    ;; 5. Anything else → keep package's behaviour ---------------
    (_ (funcall orig datum info))))

;; Clear the hash tables before each export
(defun f/clear-ids-table (&rest _)
  "Clear the used IDs table and heading cache before export."
  (setq v/used-ids-table (make-hash-table :test 'equal))
  (setq v/heading-id-cache (make-hash-table :test 'equal)))

;; Hook to clear the tables before export starts
(add-hook 'org-export-before-processing-functions #'f/clear-ids-table)

;; Suppress noisy org-babel messages during export
(defun f/suppress-babel-messages (orig-fun &rest args)
  "Suppress org-babel messages during export."
  (let ((inhibit-message t)
        (message-log-max nil))
    (apply orig-fun args)))

;; Apply message suppression to common babel functions
(advice-add 'org-babel-exp-src-block :around #'f/suppress-babel-messages)
(advice-add 'org-fontify-like-in-org-mode :around #'f/suppress-babel-messages)

;; Your existing advice with increased depth for priority
(advice-add 'org-export-get-reference
            :around #'f/stable-id–around
            '((depth . -95)))
;;; org-html5-plus-template.el --- Org -> HTML5 via external template  -*- lexical-binding: t; -*-

;; Emacs 30+ focused exporter backend using a user-editable template file.
;; Features:
;;  - Uses an external template with placeholders: {{HEAD}}, {{TITLE}},
;;    {{PREAMBLE}}, {{TOC}}, {{CONTENT}}, {{POSTAMBLE}}
;;  - Generates a single, predictable TOC with both `table-of-contents` and
;;    `text-table-of-contents` ids, avoids mutating the original INFO plist,
;;    and reuses the parse tree for performance.
;;  - Conditional preamble/postamble wrappers (omitted when empty).
;;  - Adds C-c C-e h 5 menu entry for interactive export.
;;  - Includes a publish wrapper that suppresses the usual fontification/htmlize messages.

;;; Commentary:
;; Drop this file into your `load-path` and (require 'org-html5-plus-template).
;; Configure `org-html5-plus-template-file' to point to your HTML template file
;; (or leave nil to use the built-in default).
;;
;; Template placeholders (order matters; change `org-html5-plus-template-placeholders`
;; if you use a different layout):
;;   {{HEAD}} {{TITLE}} {{PREAMBLE}} {{TOC}} {{CONTENT}} {{POSTAMBLE}}
;;
;; Example template snippet:
;; <!doctype html>
;; <html lang="en">
;; <head>
;; {{HEAD}}
;; <title>{{TITLE}}</title>
;; </head>
;; <body>
;; {{PREAMBLE}}
;; {{TOC}}
;; <main class="content">{{CONTENT}}</main>
;; {{POSTAMBLE}}
;; </body>
;; </html>

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'ox-html)

(defgroup org-html5-plus nil
  "Export Org to HTML5 using an external HTML template with placeholders."
  :group 'org-export)

(defcustom org-html5-plus-template-file nil
  "Path to an HTML template file used by the html5-template backend.
If nil, a small built-in default template will be used.
Template placeholders: {{HEAD}}, {{TITLE}}, {{PREAMBLE}}, {{TOC}},
{{CONTENT}}, {{POSTAMBLE}}."
  :type '(file)
  :group 'org-html5-plus)

(defcustom org-html5-plus-template-placeholders
  '("{{HEAD}}" "{{TITLE}}" "{{PREAMBLE}}" "{{TOC}}" "{{CONTENT}}" "{{POSTAMBLE}}")
  "List of placeholders (strings) the template uses, in this order.
Order is HEAD, TITLE, PREAMBLE, TOC, CONTENT, POSTAMBLE."
  :type '(repeat string)
  :group 'org-html5-plus)

(defcustom org-html5-template-treat-custom-toc-as-first t
  "When non-nil, treat the custom-generated TOC as the first TOC.
This makes the TOC use `id=\"table-of-contents\"` / `id=\"text-table-of-contents\"`
(with no numeric suffix).  After generating the TOC we update the
`:org-html--toc-counter` so later TOC generation remains unique."
  :type 'boolean
  :group 'org-html5-plus)


;;; Backend definition REMOVED

;;; Template reading
(defun org-html5-template--read-template ()
  "Return template text. Prefer `org-html5-plus-template-file' if set."
  (if (and org-html5-plus-template-file (file-exists-p org-html5-plus-template-file))
      (with-temp-buffer
        (insert-file-contents org-html5-plus-template-file)
        (buffer-string))
    (org-html5-template--default-template)))

(defun org-html5-template--default-template ()
  "A tiny default HTML5 template used if no external file is configured."
  (string-join
   '("<!doctype html>"
     "<html lang=\"en\">"
     "<head>"
     "{{HEAD}}"
     "  <title>{{TITLE}}</title>"
     "</head>"
     "<body>"
     "{{PREAMBLE}}"
     "<nav id=\"table-of-contents\" role=\"doc-toc\">"
     "{{TOC}}"
     "</nav>"
     "  <main class=\"content\">"
     "    {{CONTENT}}"
     "  </main>"
     "{{POSTAMBLE}}"
     "</body>"
     "</html>")
   "\n"))

;;; Body-only rendering (reuses parse tree when available)
(defun org-html5-template--body-only (info &optional parse-tree)
  "Return HTML for the document body only (no title, no TOC).
INFO is the export info plist. If PARSE-TREE is non-nil, use it instead of parsing."
  (let ((info (copy-sequence info))
        (pt (or parse-tree (org-element-parse-buffer))))
    (plist-put info :with-title nil)
    (plist-put info :with-toc nil)
    (org-export-data pt info)))

;;; TOC generation that guarantees text-table-of-contents id and matching suffix
(defun org-html5-template--generate-toc (info &optional parse-tree)
  "Generate a `<nav id=\"table-of-contents...\" role=\"doc-toc\">...</nav>` string or nil.
If `org-html5-template-treat-custom-toc-as-first' is non-nil, temporarily
clear `:org-html--toc-counter` so the generated TOC has no suffix, and then
update the counter so subsequent TOC calls are unique."
  (let ((depth (plist-get info :with-toc)))
    (when depth
      (let* ((scope (plist-get info :parse-tree))
             (pt (or parse-tree scope (org-element-parse-buffer)))
             ;; the field we will play with
             (old-counter (plist-get info :org-html--toc-counter)))
        (condition-case err
            (progn
              ;; If user requested to treat custom toc as first, temporarily set counter nil
              (when org-html5-template-treat-custom-toc-as-first
                (plist-put info :org-html--toc-counter nil))
              ;; call canonical org-html-toc (depth INFO &optional SCOPE)
              (let ((toc (org-html-toc depth info scope)))
                ;; After generating, set the counter to reflect we've emitted one more TOC
                ;; so subsequent calls will produce unique suffixes.
                (plist-put info :org-html--toc-counter (1+ (or old-counter 0)))
                ;; Return the toc HTML string (may be nil)
                toc))
          (error
           ;; restore on error, then re-signal
           (plist-put info :org-html--toc-counter old-counter)
           (signal (car err) (cdr err))))))))

;;; Template transcode
(defun org-html5-template--template (contents info)
  "Template transcode for the html5-template backend.
CONTENTS is the already-transcoded contents (unused here). INFO is the export plist."
  ;; ensure ox-html helpers are available (defensive; cheap)
  (unless (fboundp 'org-html-preamble)
    (require 'ox-html))
  (let* ((tpl (org-html5-template--read-template))
         ;; compute parse-tree once and reuse
         (parse-tree (or (plist-get info :parse-tree) (org-element-parse-buffer)))
         ;; simple fields
         (head (or (plist-get info :html-head) ""))
         (title (or (format "%s" (plist-get info :title)) ""))
         ;; preamble/postamble via canonical helpers (Emacs 30+)
         (preamble (cond
                    ((fboundp 'org-html-preamble) (or (org-html-preamble info) ""))
                    ((stringp (plist-get info :html-preamble)) (plist-get info :html-preamble))
                    (t "")))
         (postamble (cond
                     ((fboundp 'org-html-postamble) (or (org-html-postamble info) ""))
                     ((stringp (plist-get info :html-postamble)) (plist-get info :html-postamble))
                     (t "")))
         ;; generate toc and content using same parse-tree
         (toc (or (org-html5-template--generate-toc info parse-tree) ""))
         (content (org-html5-template--body-only info parse-tree))
         ;; build wrappers only when content is non-empty
         (preamble-wrapper (if (and (stringp preamble) (not (string-empty-p preamble)))
                               (format "<header class=\"site-preamble\">%s</header>" preamble)
                             ""))
         (postamble-wrapper (if (and (stringp postamble) (not (string-empty-p postamble)))
                                (format "<footer class=\"site-postamble\">%s</footer>" postamble)
                              ""))
         (replacements (list head title preamble-wrapper toc content postamble-wrapper)))
    ;; Perform placeholder replacement. Use targeted substitution to avoid scanning huge text.
    (cl-loop for ph in org-html5-plus-template-placeholders
             for rep in replacements
             do (let ((rep-str (if (stringp rep) rep (format "%s" rep))))
                  (setq tpl (replace-regexp-in-string (regexp-quote ph) rep-str tpl t t))))
    tpl))

;;;###autoload
(defun org-html5-template-export-to-html (&optional async subtreep visible-only)
  "Export current buffer to HTML using the `html5-template' backend.
Optional ASYNC SUBTREEP VISIBLE-ONLY are forwarded to `org-export-to-file'."
  (interactive)
  (let* ((outfile (concat (file-name-sans-extension (or (buffer-file-name) "untitled")) ".html")))
    (org-export-to-file 'html5-template outfile async subtreep visible-only nil nil)
    (message "Wrote %s" outfile)))

;;; Publishing wrapper (silences fontification/htmlize/indent messages)
(defun org-html5-plus-publish-to-html (plist filename pub-dir)
  "Publish a single Org file FILENAME using `html5-template' backend.
PLIST is the org-publish project plist. PUB-DIR is the publishing directory."
  (require 'org-html5-plus-template)
  (let ((org-export-in-background nil)
        (outfile (expand-file-name (concat (file-name-sans-extension (file-name-nondirectory filename)) ".html")
                                   pub-dir)))
    (make-directory (file-name-directory outfile) :parents)
    ;; suppress messages and reduce font-lock verbosity during export
    (let ((inhibit-message t)
          (font-lock-verbose nil)
          (org-src-fontify-natively (if (boundp 'org-src-fontify-natively)
                                        org-src-fontify-natively
                                      nil)))
      (with-current-buffer (find-file-noselect filename)
        (org-export-to-file 'html5-template outfile nil nil nil nil plist)))
    ;; return outfile for debugging convenience
    outfile))

;;; Ensure backend is registered: if the file was loaded but the backend wasn't,
;;; define it now. This guards against situations where top-level execution
;;; failed earlier and left feature provided but backend unregistered.
(unless (org-export-get-backend 'html5-template)
  (org-export-define-derived-backend 'html5-template 'html
    :translate-alist '((template . org-html5-template--template))))


;;; Provide
(provide 'org-html5-plus-template)
;;; org-html5-plus-template.el ends here
;; Publish
(let ((dir (expand-file-name "org-timestamps/" no-littering-var-directory)))
  (unless (file-exists-p dir) (make-directory dir t))
  (setopt org-publish-timestamp-directory dir))
(with-eval-after-load 'ox-publish
  (require '11xx-org-publish))

(:with-mode eldoc
  (:hook-into org-mode)))
;; -*- lexical-binding: t; -*-
(require '11xx-org-functions-tangle-export-helpers)

;; 0. Define global variables for your paths
(defvar 11xx.org/config/base-dir    (expand-file-name "~/.config/"))
(defvar 11xx.org/config/publish-dir (expand-file-name "~/www/11xx.org/config/"))

(defvar 11xx.org/config/index-files
  '(
    "darkman/README.org"
    "emacs/README.org"
    "hypr/README.org"
    "mpd/README.org"
    "shell/README.org"
    )
  "Files whose basename will be renamed to \"index\" by `org-publish-rename-completion'")

(defvar 11xx.org/config/other-files
  '(
    "emacs/emacs-notes.org"
    "shell/notes.org"
    )
  "Publish with basename as-is (default export behaviour)")

;; (defvar my-config-asset-files
;;   '("emacs/style.css" "shell/script.js" "mpd/icon.png"))

(defvar 11xx.org/config/all-files
  (append 11xx.org/config/index-files 11xx.org/config/other-files))

(defun org-publish-rename-completion (plist)
  "After publishing, rename README.html files to index.html.

Based on `11xx.org/config/index-files'."
  ;; For each file in 11xx.org/config/index-files, check if the corresponding
  ;; README.html exists and rename it to index.html
  (dolist (org-file 11xx.org/config/index-files)
    (let* ((html-file (concat (file-name-sans-extension org-file) ".html"))
           (full-html-path (expand-file-name html-file 11xx.org/config/publish-dir))
           (index-path (expand-file-name
                        "index.html"
                        (file-name-directory full-html-path))))
      (when (file-exists-p full-html-path)
        (rename-file full-html-path index-path t)))))

;; (setq org-publish-use-timestamps-flag nil)
;; (setq org-export-async-debug t)

(add-or-replace-to-alist
 'org-publish-project-alist
 `(;; A: Index files → index.html
   ("11xx.org_config_files"
    :base-directory ,11xx.org/config/base-dir
    :publishing-directory ,11xx.org/config/publish-dir
    :base-extension "org"
    :recursive nil
    :include ,11xx.org/config/all-files
    :publishing-function org-html5-plus-publish-to-html
    ;; options
    :html-head "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<link rel=\"stylesheet\" href=\"../../static/tw-out.css\">"
    :auto-preamble t
    :section-numbers nil
    :with-author nil
    :with-date nil
    :with-email nil
    :with-latex nil
    :with-timestamps nil
    :with-toc 3
    :force t
    :auto-sitemap t
    :completion-function org-publish-rename-completion)

   ;; Aggregate
   ("11xx.org_config"
    :components ("11xx.org_config_files"))
   ))

(provide '11xx-org-publish)

(provide '11xx-org)
