;; -*- lexical-binding: t; -*-

(defun org-babel-repeat-previous-src-block ()
  "Copy previous src block excluding the content."
  (interactive)
  (let (result)
    (save-excursion
      (org-babel-previous-src-block)
      (let ((element (org-element-at-point)))
        (when (eq (car element) 'src-block)
          (let* ((pl (cadr element))
                 (lang (plist-get pl :language))
                 (switches (plist-get pl :switches))
                 (parms (plist-get pl :parameters)))
            (setq result
                  (format
                   (concat "\n#+begin_src %s\n"
                           "\n"
                           "#+end_src\n")
                   (mapconcat #'identity
                              (delq nil (list lang switches parms))
                              " ")))))))
    (and result (insert result))
    (forward-line -2))
  (recenter-top-bottom))
(defun f/eval-string (string)
  "Read STRING and evaluate its lisp expression.

Returns STRING if it doesn't start with \"(\"."
  (if (string-match-p "^(" string)
      (eval (read string))
    string))

(defun tdir (&optional path)
  "Expand PATH given to \"tangle-dir\" property.

If the \"tangle-dir\" property exists and is a directory, return the
expanded directory path concatenated with the provided PATH.

If the property exists and is an expression, evaluate it and return the
expanded result.

If the property is not found, use the base directory of the current
buffer concatenated with the provided PATH."
  (let ((dir (string-trim (f/eval-string (org-entry-get nil "tangle-dir" t)) nil "/"))
        (file (if path (string-trim path "/" nil))))
    (if dir
        (expand-file-name file dir)
      (error
       "tdir failed in getting a directory. Aborting tangle from '%s'."
       (buffer-file-name)))))
(defvar org-additional-electric-pairs '((?= . ?=) (?' . ?'))
  "Additional electric pairs for Org Mode.")

(defun f/org-electric-pairs-add-local ()
  "Append list `org-additional-electric-pairs' to `electric-pair-pairs'."
  (setq-local electric-pair-pairs
              (append electric-pair-pairs org-additional-electric-pairs))
  (setq-local electric-pair-text-pairs electric-pair-pairs))

(defun f/org-electric-pairs-add (pair)
  "Add an electric PAIR to `org-additional-electric-pairs` and update `electric-pair-pairs`."
  (add-to-list 'org-additional-electric-pairs pair)
  (f/org-electric-pairs-add-local))

(add-hook 'org-mode-hook #'f/org-electric-pairs-add-local)
;; override the default
(with-eval-after-load 'org
  (defun org-babel-noweb-wrap (&optional regexp)
    "Return regexp matching a Noweb reference.

Match any reference, or only those matching REGEXP, if non-nil.

When matching, reference is stored in match group 1."
    (rx-to-string
     `(and (or "<<" "«")
           (group
            (not (or " " "\t" "\n"))
            (? (*? any) (not (or " " "\t" "\n"))))
           (or ">>" "»")))))

;;;###autoload
(defun f/org-babel-noweb-wrap-insert-chars ()
  "Insert \"«\" and \"»\" "
  (interactive)
  (insert "«»")
  (backward-char))

(f/org-electric-pairs-add '(?« . ?»))
(setup org
  (:bind "C-c C-;" org-babel-repeat-previous-src-block
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
         "M-D"   backward-kill-word
         ;; "M-h"   backward-delete-char ; was `org-mark-element'
         ;; "M-H"   backward-kill-word ; was `org-mark-element' in org map
         )

  ;; [[https://orgmode.org/manual/Activation.html][src]]
  ;; Enable Org-mode commands to be available anywhere.
  (:global "C-c o l" org-store-link
           "C-c o a" org-agenda
           "C-c o c" org-capture)

  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((haskell . t)
             ;; (async   . t) ; from ob-async
             (shell   . t)
             (C       . t))))

  ;; Disable angle bracket syntax highlighting/matching
  (:hook (lambda()
           (modify-syntax-entry ?< "." org-mode-syntax-table)
           (modify-syntax-entry ?> "." org-mode-syntax-table)))

  ;; (:with-mode org-num-mode
  ;;   (:load-after org)
  ;;   (:hook-into org-mode))

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
 org-src-window-setup 'current-window)
  ) ; "(setup org..." ends here

;; Visual Fill Column
;; [[https://github.com/daviwil/emacs-from-scratch/blob/master/Emacs.org#center-org-buffers][Emacs From Scratch/Emacs.org#Center Org Buffers]].
(setup (:package visual-fill-column)
  (:load-after org)
  (:option visual-fill-column-width 120 ; use with `display-fill-column-indicator-mode'
           visual-fill-column-center-text t)
  (:hook-into org-mode))

(setup (:package org-bulletproof)
  (:load-after org)
  (:hook-into org-mode))

;; usage in local file variables: `eval: (add-hook 'before-save-hook #'org-gfm-export-to-markdown nil t)'
(setup (:package ox-gfm)
  (:load-after org))

;; (:package org-auto-tangle)
;; [[https://www.youtube.com/watch?v=D3FzMPZm7vY][Write Everything In Emacs Org Mode? You NEED This Plugin! - YouTube]]
;; org-auto-tangle: Org babel tangle file on save
;; [[https://github.com/yilkalargaw/org-auto-tangle][yilkalargaw/org-auto-tangle: a simple emacs package to allow org file tangling upon save]]
;; (:require org-auto-tangle)
;; (:hook org-auto-tangle-mode)
;; Note about auto tangle: Since it uses async.el that spawns a new
;; Emacs instance, if for example :tangle is used containing a
;; function that is not the default it may throw the error:
;; > error in process sentinel: async-when-done: Symbol’s function definition is void: function-name
;; See https://stackoverflow.com/a/22843310
;;
;; Two options are available: Use only default functions and paths
;; for tangling or include the desired functions to be passed in the
;; async Emacs by customizing auto-tangle's async-start function
;; (which idk how to do).
(defun f/org-export-dispatch-disable-whitespace-mode (&rest args)
  "Disable `whitespace-mode' for the Org Export Dispatch Buffer."
  (let ((buf (get-buffer "*Org Export Dispatcher*")))
    (when buf
      (with-current-buffer buf
        (setq-local show-trailing-whitespace nil)))))

(advice-add 'org-export--dispatch-action
            :before #'f/org-export-dispatch-disable-whitespace-mode)
(setup (:package org-appear)
  (:load-after org)
  ;; Toggle for links display set in (setup org)
  (:option org-appear-autolinks 'just-brackets) ; nil is default
  (:hook-into org-mode))
(setq org-fold-core-style 'text-properties)

(provide '11xx-org)
