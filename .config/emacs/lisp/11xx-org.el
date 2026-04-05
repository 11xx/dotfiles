;; -*- lexical-binding: t; -*-
(setq org-modules '(ol-info ol-docview ol-doi))

(require '11xx-org-functions)
;; (setup org
;;   ;; Disable angle bracket syntax highlighting/matching
;;   (:hook (lambda()
;;            (modify-syntax-entry ?< "." org-mode-syntax-table)
;;            (modify-syntax-entry ?> "." org-mode-syntax-table))))

(setup (:elpaca org-contrib)
  (:load-after org)
  (require 'org-eldoc) ; shows inherited code block properties
  )

(setup org
  (:with-map org-mode-map
    (:bind
     "C-c C-;" org-babel-repeat-previous-src-block
     "C-M-p" org-previous-visible-heading ; was `backward-list'
     "C-M-n" org-next-visible-heading ; was `forward-list'
     "C-c o t l" org-toggle-link-display
     ;; Meta indentation
     "M-F" org-metaright
     "M-B" org-metaleft
     "M-P" org-metaup
     "M-N" org-metadown
     "C-c o p" org-kill-full-outline-path))

  ;; [[https://orgmode.org/manual/Activation.html][src]]
  ;; Enable Org-mode commands to be available anywhere.
  (:global-set
   "C-c o l" org-store-link
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
   org-edit-src-content-indentation 0
   org-adapt-indentation nil
   org-ellipsis " ▾"
   org-babel-default-header-args:emacs-lisp '((:lexical . yes))
   org-image-actual-width nil
   org-src-window-setup 'current-window)

(setup (:elpaca org-bulletproof)
  (:load-after org)
  (:hook-into org-mode))
(setup (:elpaca visual-fill-column)
  (:load-after org)
  (:global-set "C-c d c" visual-fill-column-mode)
  (setopt visual-fill-column-width 130 ; `display-fill-column-indicator-mode's width
          visual-fill-column-center-text t))
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
  (setopt org-hide-emphasis-markers t) ; needs to be t
  (:hook-into org-mode))
(setup (:elpaca org-modern)
  (setopt org-modern-block-fringe nil)
  (global-org-modern-mode))
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

(with-eval-after-load 'ox
  (require 'org-stable-ids)
  (org-stable-ids-setup)
  (keymap-global-set "C-c o i" #'org-stable-id-get-create))
;; Publish
(let ((dir (expand-file-name "org-timestamps/" no-littering-var-directory)))
  (unless (file-exists-p dir) (make-directory dir t))
  (setopt org-publish-timestamp-directory dir))

(:with-mode eldoc
  (:hook-into org-mode))

) ;; (setup org ends here
(when (file-exists-p "~/www/11xx.org/lisp/11xx-org-publish.el")
  (add-to-list 'load-path "~/www/11xx.org/lisp/")
  (with-eval-after-load 'ox-publish
    (require '11xx-org-publish)))
(setup ob-lob
  (:load-after org)
  (org-babel-lob-ingest "~/org/.setup/xdg.org.setup")
  (require 'org-bitwarden))

(provide '11xx-org)
