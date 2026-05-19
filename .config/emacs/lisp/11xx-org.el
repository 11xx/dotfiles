;; (setq org-modules '(ol-info ol-docview ol-doi))  -*- lexical-binding: t; -*-

(require '11xx-org-functions)

(use-package org-contrib
  :after org
  :config
  (require 'org-eldoc))

(use-package org
  :ensure nil
  :bind (:map org-mode-map
              ("C-c C-;" . org-babel-repeat-previous-src-block)
              ("C-M-p" . org-previous-visible-heading)
              ("C-M-n" . org-next-visible-heading)
              ("C-c o t l" . org-toggle-link-display)
              ("M-F" . org-metaright)
              ("M-B" . org-metaleft)
              ("M-P" . org-metaup)
              ("M-N" . org-metadown)
              ("C-c o p" . org-kill-full-outline-path))
  :init
  (keymap-global-set "C-c o l" #'org-store-link)
  (keymap-global-set "C-c o a" #'org-agenda)
  (keymap-global-set "C-c o c" #'org-capture)
  (setq org-edit-src-content-indentation 0
        org-adapt-indentation nil
        org-ellipsis " ▾"
        org-babel-default-header-args:emacs-lisp '((:lexical . yes))
        org-image-actual-width nil
        org-src-window-setup 'current-window)
  :config
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((haskell t)
     (shell t)
     (C t)))
  (add-hook 'org-mode-hook
            (lambda ()
              (modify-syntax-entry ?< "." org-mode-syntax-table)
              (modify-syntax-entry ?> "." org-mode-syntax-table)))
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
             ("sa" . "seealso")))
    (add-to-list 'org-structure-template-alist begin)))

(use-package org-bulletproof
  :after org
  :hook (org-mode . org-bulletproof-mode))
(use-package visual-fill-column
  :after org
  :bind (("C-c d c" . visual-fill-column-mode))
  :init
  (setq visual-fill-column-width 130
        visual-fill-column-center-text t))
(defun org-export-dispatch-disable-whitespace (&rest args)
  "Disable trailing whitespace in Org Export Dispatch buffer."
  (let ((buf (get-buffer "*Org Export Dispatcher*")))
    (when buf
      (with-current-buffer buf
        (setq-local show-trailing-whitespace nil)))))

(advice-add 'org-export--dispatch-action
            :before #'org-export-dispatch-disable-whitespace)
(use-package org-appear
  :disabled
  :after org
  :hook (org-mode . org-appear-mode)
  :init
  (setq org-appear-autolinks 'just-brackets
        org-hide-emphasis-markers t))
(use-package org-modern
  :init
  (setopt org-modern-block-fringe nil)
  :config
  (global-org-modern-mode))
(use-package org-transclusion
  :bind (:map org-mode-map
              ("C-c o t a" . org-transclusion-add)
              ("C-c o t A" . org-transclusion-add-all)
              ("C-c o t r" . org-transclusion-remove)))
(setopt org-export-with-sub-superscripts nil ; interpret "_" and "^" for export.
        org-html-html5-fancy t
        org-export-in-background nil ; export async default: Use 'M-x org-export-stack' to display current processes:
        org-html-validation-link "" ; remove validade xml
        )
(use-package htmlize
  :init
  (setq org-html-head-include-default-style nil
        org-html-htmlize-output-type 'css
        htmlize-html-charset "UTF-8"
        htmlize-face-overrides '(whitespace-missing-newline-at-eof
                                 (:foreground nil :background nil))))
(use-package ox-gfm)

(use-package ox-md-title
  :vc (:url "https://github.com/jeffkreeftmeijer/ox-md-title.el")
  :config
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


(use-package org-stable-ids
  :vc (:url "https://codeberg.org/useless-utils/org-stable-ids")
  :init
  (keymap-global-set "C-c o i" #'org-stable-ids-get-create)
  :config
  (org-stable-ids-enable))
;; Publish
(let ((dir (expand-file-name "org-timestamps/" no-littering-var-directory)))
  (unless (file-exists-p dir) (make-directory dir t))
  (setopt org-publish-timestamp-directory dir))
(use-package org-tangle-dir
  :vc (:url "https://codeberg.org/useless-utils/org-tangle-dir")
  :config
  (defun tdir-set-heading-property ()
      "Set :tangle-dir: for the current heading to (tdir-base \"SLUG\").
SLUG is derived from the heading title and confirmed in the minibuffer."
      (interactive)
      (let* ((title (substring-no-properties (org-entry-get nil "ITEM")))
             (slug  (org-stable-ids--slugify title))
             (slug  (read-string "Slug for tdir-base: " slug))
             (value (format "(tdir-base \"%s\")" slug)))
        (org-set-property "tangle-dir" value)
        (message "Set :tangle-dir: %s" value)))

  (with-eval-after-load 'org
    (keymap-set org-mode-map "C-c C-x T" #'tdir-set-heading-property)))
(when (file-exists-p "~/www/11xx.org/lisp/11xx-org-publish.el")
  (add-to-list 'load-path "~/www/11xx.org/lisp/")
  (with-eval-after-load 'ox-publish
    (require '11xx-org-publish)))
(use-package ob-lob
  :ensure nil
  :after org
  :config
  (org-babel-lob-ingest (expand-file-name "lob/xdg-vars.org" user-emacs-directory))

  (use-package org-bitwarden
    :vc (:url "https://codeberg.org/useless-utils/org-bitwarden")
    :config
    (require 'org-bitwarden)))

(provide '11xx-org)
