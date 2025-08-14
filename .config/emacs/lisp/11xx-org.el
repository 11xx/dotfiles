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

   ;;; Use HTML5 on export
   org-html-html5-fancy t
   ;;; UI
   org-ellipsis " ▾"
   org-hide-emphasis-markers t
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

  ;; Publish
  (let ((dir (expand-file-name "org-timestamps/" no-littering-var-directory)))
    (unless (file-exists-p dir) (make-directory dir t))
    (setopt org-publish-timestamp-directory dir))
  (with-eval-after-load 'ox-publish
    (require '11xx-org-publish))

  (:with-mode eldoc
    (:hook-into org-mode)))

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
(setopt org-export-with-sub-superscripts nil)
(setup (:elpaca htmlize)
  (setopt org-html-htmlize-output-type 'css ; 'inline-css
           htmlize-html-charset "UTF-8")
  (setopt htmlize-face-overrides '(whitespace-missing-newline-at-eof
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

(defun f/ensure-unique-id (base-id datum)
  "Ensure BASE-ID is unique, adding disambiguation if needed."
  (unless v/used-ids-table
    (setq v/used-ids-table (make-hash-table :test 'equal)))

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
    final-id))

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

;; Clear the hash table before each export
(defun f/clear-ids-table (&rest _)
  "Clear the used IDs table before export."
  (setq v/used-ids-table (make-hash-table :test 'equal)))

;; Hook to clear the table before export starts
(add-hook 'org-export-before-processing-functions #'f/clear-ids-table)

;; Your existing advice with increased depth for priority
(advice-add 'org-export-get-reference
            :around #'f/stable-id–around
            '((depth . -95)))
(setup (:elpaca org-modern)
  (setopt org-modern-block-fringe nil)
  (:hook-into org-mode))
(setup (:elpaca org-transclusion)
  (:with-map org-mode-map
    (:bind "C-c o t a" org-transclusion-add
           "C-c o t A" org-transclusion-add-all
           "C-c o t r" org-transclusion-remove)))

(provide '11xx-org)
