;; -*- lexical-binding: t; -*-

(require '11xx-org-functions)

;; (setup org
;;   ;; Disable angle bracket syntax highlighting/matching
;;   (:hook (lambda()
;;            (modify-syntax-entry ?< "." org-mode-syntax-table)
;;            (modify-syntax-entry ?> "." org-mode-syntax-table))))

;; (setup (:elpaca org-contrib))

(use-package org
  :bind (:map org-mode-map
   ("C-c C-;" . org-babel-repeat-previous-src-block)
   ;; "C-c C-'" org-babel-repeat-previous-src-block-reverse ;; use `org-babel-demarcate-block' instead #DONE-TO-SEND-CEMETARY
   ("C-M-p" . org-previous-visible-heading) ; was `backward-list'
   ("C-M-n" . org-next-visible-heading) ; was `forward-list'
   ("C-c o t l" . org-toggle-link-display)
   ;; Meta indentation ; `S' for Shift not working for some reason
   ("M-F" . org-metaright)
   ("M-B" . org-metaleft)
   ("M-P" . org-metaup)
   ("M-N" . org-metadown)
   ;; Cursor
   ;; "C-M-d" ; was down-list
   ("C-M-d" . backward-delete-char) ; was down-list
   ("M-D" . backward-kill-word)
   ;; "M-h"   backward-delete-char ; was `org-mark-element'
   ;; "M-H"   backward-kill-word ; was `org-mark-element' in org map
   ("C-c o p" . org-kill-full-outline-path))

  ;; [[https://orgmode.org/manual/Activation.html][src]]
  ;; Enable Org-mode commands to be available anywhere.
  :bind (("C-c o l" . org-store-link)
         ("C-c o a" . org-agenda)
         ("C-c o c" . org-capture))

  :config
  ;; Move this to file local
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((haskell . t)
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
           '(("sh" . "src shell")
             ("el" . "src emacs-lisp")
             ("py" . "src python")
             ("js" . "src javascript")
             ("css" . "src css")
             ("cc" . "src conf")
             ("hs" . "src haskell")
             ("sd" . "src systemd")
             ("y" . "src yaml")))
    (add-to-list 'org-structure-template-alist begin))

  (setopt
 ;;; Org mode version 9.5:
   ;; ~org-adapt-indentation~ now defaults to ~nil~
   org-adapt-indentation nil ;; testing nil [2022-03-31 Thu 07:34:31]

   ;;; Use HTML5 on export
   org-html-html5-fancy t
   ;;; UI
   org-ellipsis " ▾"
   org-hide-emphasis-markers t
   ;;; Publish
   org-publish-project-alist
   '(("front-end-completo-2-markdown"
      :base-directory "~/org/learning/web/front-end/2.0/org/"
      :base-extension "org"
      :publishing-directory "~/org/learning/web/front-end/2.0/publish/"
      :recursive t
      :publishing-function org-html-publish-to-html
      :headline-levels 4             ; Just the default for this project.
      :auto-preamble t)
     ("front-end-completo-2-static"
      :base-directory "~/org/learning/web/front-end/2.0/org/"
      :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf"
      :publishing-directory "~/org/learning/web/front-end/2.0/publish/"
      :recursive t
      :publishing-function org-publish-attachment)
     ("org"
      :components ("front-end-completo-2-markdown" "front-end-completo-2-static")))
   org-publish-timestamp-directory (expand-file-name "org-timestamps" no-littering-var-directory)
   ;;; Exporting
   ;; export async default:
   ;; Use 'M-x org-export-stack' to display current processes:
   org-export-in-background nil
   org-html-validation-link "" ; remove validade xml
   ;;; Properties
   ;; org-use-property-inheritance t ; Apparently slows down searches when on.
   ;;; Default header-args for evaluation
   org-babel-default-header-args:emacs-lisp '((:lexical . yes))
   org-image-actual-width nil
   ;; Edit src blocks in the current window instead of split
   org-src-window-setup 'current-window))

;; Visual Fill Column
;; [[https://github.com/daviwil/emacs-from-scratch/blob/master/Emacs.org#center-org-buffers][Emacs From Scratch/Emacs.org#Center Org Buffers]].
(use-package visual-fill-column
  :ensure t
  :after org
  :custom ((visual-fill-column-width 130) ; use with `display-fill-column-indicator-mode'
           (visual-fill-column-center-text t))
  :hook org-mode)

(use-package org-bulletproof
  :ensure t
  :after org
  :hook org-mode)

;; usage in local file variables: `eval: (add-hook 'before-save-hook #'org-gfm-export-to-markdown nil t)'
(use-package ox-gfm
  :ensure t
  :after org)
(defun f/org-export-dispatch-disable-whitespace-mode (&rest args)
  "Disable `whitespace-mode' for the Org Export Dispatch Buffer."
  (let ((buf (get-buffer "*Org Export Dispatcher*")))
    (when buf
      (with-current-buffer buf
        (setq-local show-trailing-whitespace nil)))))

(advice-add 'org-export--dispatch-action
            :before #'f/org-export-dispatch-disable-whitespace-mode)
(use-package org-appear
  :ensure t
  :after org
  ;; Toggle for links display set in (setup org)
  :custom ((org-appear-autolinks 'just-brackets)) ; nil is default
  :hook org-mode)
(setopt org-fold-core-style 'text-properties)
(setup (:elpaca htmlize)
  (setopt org-html-htmlize-output-type 'css ; 'inline-css
           htmlize-html-charset "UTF-8")
  (setopt htmlize-face-overrides '(whitespace-missing-newline-at-eof
                                   (:foreground nil :background nil))))
(setup (:elpaca org-modern)
  (setopt org-modern-block-fringe nil)
  (:hook-into org-mode))

(provide '11xx-org)
