;;; ox-html-template.el --- Org -> HTML via external template  -*- lexical-binding: t; -*-

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
;; Drop this file into your `load-path` and (require 'ox-html-template).
;; Configure `org-html-template-file' to point to your HTML template file
;; (or leave nil to use the built-in default).
;;
;; Template placeholders (order matters; change `org-html-template-placeholders`
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

(defgroup org-html-template nil
  "Export Org to HTML using an external HTML template with placeholders."
  :group 'org-export)

(defcustom org-html-template-file nil
  "Path to an HTML template file used by the `html-template' backend.
If nil, a small built-in default template will be used.
Template placeholders: {{HEAD}}, {{TITLE}}, {{PREAMBLE}}, {{TOC}},
{{CONTENT}}, {{POSTAMBLE}}."
  :type '(file)
  :group 'org-html-template)

(defcustom org-html-template-placeholders
  '("{{HEAD}}" "{{TITLE}}" "{{PREAMBLE}}" "{{TOC}}" "{{CONTENT}}" "{{POSTAMBLE}}")
  "List of placeholders (strings) the template uses, in this order.
Order is HEAD, TITLE, PREAMBLE, TOC, CONTENT, POSTAMBLE."
  :type '(repeat string)
  :group 'org-html-template)

(defcustom org-html-template-treat-custom-toc-as-first t
  "When non-nil, treat the custom-generated TOC as the first TOC.
This makes the TOC use `id=\"table-of-contents\"` / `id=\"text-table-of-contents\"`
(with no numeric suffix).  After generating the TOC we update the
`:org-html--toc-counter` so later TOC generation remains unique."
  :type 'boolean
  :group 'org-html-template)


;;; Backend definition REMOVED

;;; Template reading
(defun org-html-template--read-template (info)
  "Return template text. Prefer `org-html-template-file' if set."
  (let*  ((tpl-file (or (plist-get info :html-template-file)
                        (and org-html-template-file (file-exists-p org-html-template-file))))
          (tpl-read (if tpl-file
                        (with-temp-buffer
                          (insert-file-contents tpl-file)
                          (buffer-string)))))
    (if tpl-read
        tpl-read
      (org-html-template--default-template))))

(defun org-html-template--default-template ()
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
     "{{TOC}}"
     "  <main class=\"content\">"
     "    {{CONTENT}}"
     "  </main>"
     "{{POSTAMBLE}}"
     "</body>"
     "</html>")
   "\n"))

;;; Body-only rendering (reuses parse tree when available)
(defun org-html-template--body-only (info &optional parse-tree)
  "Return HTML for the document body only (no title, no TOC).
INFO is the export info plist. If PARSE-TREE is non-nil, use it instead of parsing."
  (let ((info (copy-sequence info))
        (pt (or parse-tree (org-element-parse-buffer))))
    (plist-put info :with-title nil)
    (plist-put info :with-toc nil)
    (org-export-data pt info)))

;;; TOC generation that guarantees text-table-of-contents id and matching suffix
(defun org-html-template--generate-toc (info &optional parse-tree)
  "Generate a `<nav id=\"table-of-contents...\" role=\"doc-toc\">...</nav>` string or nil.
If `org-html-template-treat-custom-toc-as-first' is non-nil, temporarily
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
              (when org-html-template-treat-custom-toc-as-first
                (plist-put info :org-html--toc-counter nil))
              ;; call canonical org-html-toc (depth INFO &optional SCOPE)
              (let ((toc (org-html-toc depth info scope)))
                ;; After generating, set the counter to reflect we've emitted one more TOC
                ;; so subsequent calls will produce unique suffixes.
                (plist-put info :org-html--toc-counter (1+ (or old-counter 0)))
                ;; Return the toc HTML string (may be nil)
                (when toc
                  (concat
                   "<nav id=\"table-of-contents\" role=\"doc-toc\">"
                   toc
                   "</nav>"))))
          (error
           ;; restore on error, then re-signal
           (plist-put info :org-html--toc-counter old-counter)
           (signal (car err) (cdr err))))))))

;;; Template transcode
(defun org-html-template--template (contents info)
  "Template transcode for the `html-template' backend.
CONTENTS is the already-transcoded contents (unused here). INFO is the export plist."
  ;; ensure ox-html helpers are available (defensive; cheap)
  (unless (fboundp 'org-html-preamble)
    (require 'ox-html))
  (let* ((tpl (org-html-template--read-template info))
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
         (toc (or (org-html-template--generate-toc info parse-tree) ""))
         (content (org-html-template--body-only info parse-tree))
         ;; build wrappers only when content is non-empty
         (preamble-wrapper (if (and (stringp preamble) (not (string-empty-p preamble)))
                               (format "<header class=\"site-preamble\">%s</header>" preamble)
                             ""))
         (postamble-wrapper (if (and (stringp postamble) (not (string-empty-p postamble)))
                                (format "<footer class=\"site-postamble\">%s</footer>" postamble)
                              ""))
         (replacements (list head title preamble-wrapper toc content postamble-wrapper)))
    ;; Perform placeholder replacement. Use targeted substitution to avoid scanning huge text.
    (cl-loop for ph in org-html-template-placeholders
             for rep in replacements
             do (let ((rep-str (if (stringp rep) rep (format "%s" rep))))
                  (setq tpl (replace-regexp-in-string (regexp-quote ph) rep-str tpl t t))))
    tpl))

;;;###autoload
(defun org-html-template-export-to-html (&optional async subtreep visible-only)
  "Export current buffer to HTML using the `html-template' backend.
Optional ASYNC SUBTREEP VISIBLE-ONLY are forwarded to `org-export-to-file'."
  (interactive)
  (let* ((outfile (concat (file-name-sans-extension (or (buffer-file-name) "untitled")) ".html")))
    (org-export-to-file 'html-template outfile async subtreep visible-only nil nil)
    (message "Wrote %s" outfile)))

;;; Publishing wrapper (silences fontification/htmlize/indent messages)
(defun org-html-template-publish-to-html (plist filename pub-dir)
  "Publish a single Org file FILENAME using `html-template' backend.
PLIST is the org-publish project plist. PUB-DIR is the publishing directory."
  (require 'org-html-template)
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
        (org-export-to-file 'html-template outfile nil nil nil nil plist)))
    ;; return outfile for debugging convenience
    outfile))

;;; Ensure backend is registered: if the file was loaded but the backend wasn't,
;;; define it now. This guards against situations where top-level execution
;;; failed earlier and left feature provided but backend unregistered.
(unless (org-export-get-backend 'html-template)
  (org-export-define-derived-backend 'html-template 'html
    :translate-alist '((template . org-html-template--template))))


;;; Provide
(provide 'ox-html-template)
;;; ox-html-template.el ends here
