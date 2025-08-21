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
