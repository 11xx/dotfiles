;; -*- lexical-binding: t; -*-
(require '11xx-org-functions-tangle-export-helpers)
(require 'org-html5-plus-template)

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

(defun org-selective-index-publisher-html5-plus-template (index-files-var)
  "Return a publishing function that renames files based on INDEX-FILES-VAR.

INDEX-FILES-VAR should be a symbol that holds the list of files to be
renamed to 'index.html'."
  (lambda (plist filename pub-dir)
    "Publish FILENAME, renaming to 'index.html' if in the list."
    (let* ((base-dir (plist-get plist :base-directory))
           (relative-source (file-relative-name filename base-dir))
           ;; Use the variable passed to the factory
           (is-index-file (member relative-source (symbol-value index-files-var)))
           (output-file
            (if is-index-file
                (expand-file-name "index.html"
                                  (expand-file-name (file-name-directory relative-source) pub-dir))
              (expand-file-name (concat (file-name-sans-extension (file-name-nondirectory filename)) ".html")
                                (expand-file-name (file-name-directory relative-source) pub-dir)))))
      (org-export-to-file 'html5-plus filename
        :output-file output-file
        :publishing-directory pub-dir
        :extra plist)
      output-file)))

(defun org-selective-index-publisher-html (index-files-var)
  "Return a publishing function that uses org-export-to-file with
the default HTML backend, but with custom output filenames based on
the list stored in the symbol INDEX-FILES-VAR."
  (lambda (plist filename pub-dir)
    "Publish FILENAME to PUB-DIR using the 'html backend.
Files listed in the `index-files-var` symbol are published as
`index.html` in their respective subdirectories."
    (let* ((base-dir (plist-get plist :base-directory))
           (relative-source (file-relative-name filename base-dir))
           (is-index-file (member relative-source (symbol-value index-files-var)))
           (output-file
            (if is-index-file
                (expand-file-name "index.html" pub-dir)
              (expand-file-name (concat (file-name-sans-extension (file-name-nondirectory filename)) ".html")
                                pub-dir))))

      ;; First visit the input file, then export it
      (with-current-buffer (find-file-noselect filename)
        (org-export-to-file 'html output-file nil nil nil nil plist))

      ;; Return the path of the generated file
      output-file)))



(setq org-publish-use-timestamps-flag nil)
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
    :publishing-function ,(org-selective-index-publisher-html '11xx.org/config/index-files)
    ;; options
    :html-head "<link rel=\"stylesheet\" href=\"../../static/tw-out.css\">"
    :html-head-extra ,(string-join
                       '("<script defer type=\"module\" src=\"../../static/js/toc-sidebar.js\"></script>"
                         "<script defer type=\"module\" src=\"../../static/js/toc-highlight.js\"></script>")
                       "\n")
    :auto-preamble t
    :section-numbers nil
    :with-author nil
    :with-email nil
    :with-toc 3

    :html-doctype "html5"
    :html-html5-fancy t

    :force t
    :auto-sitemap nil)

   ;; Aggregate
   ("11xx.org_config"
    :components ("11xx.org_config_files"))
   ))

(provide '11xx-org-publish)
