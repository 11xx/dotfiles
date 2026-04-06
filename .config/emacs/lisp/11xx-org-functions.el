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
(defvar 11xx--tdir-allowed-functions
  '(tdir-base
    expand-file-name
    concat
    xdg-config-home
    xdg-data-home
    xdg-cache-home
    xdg-bin-home
    xdg-config-dirs
    xdg-data-dirs
    getenv
    xdg-runtime-dir
    )
  "Side-effect-free functions permitted inside :tangle-dir: sexp values.
All must return strings or path components.")

(defun f/tdir-safe-form-p (form)
  "Return t if FORM is safe to evaluate as a :tangle-dir: expression.
Safe means: a self-evaluating atom, or a list whose car is in
`11xx--tdir-allowed-functions' and whose every argument is also safe."
  (cond
   ((stringp form)          t)
   ((numberp form)          t)
   ((memq form '(t nil))    t)
   ((keywordp form)         t)
   ((and (consp form)
         (symbolp (car form))
         (memq (car form) 11xx--tdir-allowed-functions)
         (cl-every #'f/tdir-safe-form-p (cdr form)))
    t)
   (t nil)))

(defun f/eval-tdir-sexp (string)
  "Safely evaluate STRING as a :tangle-dir: property value.
Returns STRING as-is if it does not start with '('."
  (let ((s (string-trim string)))
    (if (not (string-prefix-p "(" s))
        s
      (let ((form (condition-case err
                      (read s)
                    (error (user-error
                            "tdir: malformed sexp in :tangle-dir: %s — %s" s err)))))
        (unless (f/tdir-safe-form-p form)
          (user-error
           "tdir: unsafe form in :tangle-dir: %s\n  Only %s with literal/whitelisted args are permitted"
           form 11xx--tdir-allowed-functions))
        (let ((result (eval form t)))
          (unless (stringp result)
            (user-error "tdir: :tangle-dir: sexp must return a string, got: %S" result))
          result)))))

(defvar tdir--resolving nil
  "Stack of heading positions currently being resolved.
Used to detect circular :tangle-dir: references.")

(defun tdir--effective-dir ()
  "Resolve :tangle-dir: for the current heading without Org's built-in
property inheritance, to retain full control over sexp evaluation.

- Plain string → returned directly.
- Sexp         → validated and evaluated; circular refs cause a user-error.
- Missing      → walks up the outline tree recursively."
  (let* ((raw (org-entry-get nil "tangle-dir" nil))
         (pos (save-excursion (org-back-to-heading t) (point))))
    (cond
     ((and raw (not (string-prefix-p "(" (string-trim raw))))
      (string-trim raw nil "/"))

     (raw
      (when (memq pos tdir--resolving)
        (user-error
         "tdir: circular :tangle-dir: at '%s' — use `tdir-base' in properties, not `tdir'"
         (org-entry-get nil "ITEM")))
      (let ((tdir--resolving (cons pos tdir--resolving)))
        (string-trim (f/eval-tdir-sexp (string-trim raw)) nil "/")))

     (t
      (save-excursion
        (unless (org-up-heading-safe)
          (user-error "tdir: no :tangle-dir: property found in heading hierarchy"))
        (tdir--effective-dir))))))

(defun tdir-base (&optional subdir)
  "Return the parent heading's effective tangle-dir, joined with SUBDIR.
Use in :tangle-dir: property values for hierarchy-relative paths:

  :tangle-dir: (tdir-base \"tasks\")

For externally-rooted paths, use expand-file-name directly:

  :tangle-dir: (expand-file-name \"nnn/plugins\" (xdg-config-home))"
  (save-excursion
    (unless (org-up-heading-safe)
      (user-error "tdir-base: no parent heading"))
    (let ((parent-dir (tdir--effective-dir)))
      (if subdir
          (expand-file-name (string-trim subdir "/" nil) parent-dir)
        parent-dir))))

(defun tdir (&optional path)
  "Return the effective tangle directory for the current Org entry,
optionally joined with PATH via `expand-file-name'.

Use in :tangle src block headers:
  :tangle (tdir \"filename.yml\")

For :tangle-dir: property values, use `tdir-base' or `expand-file-name'."
  (let ((dir (tdir--effective-dir)))
    (if path
        (expand-file-name (string-trim path "/" nil) dir)
      dir)))

(defun f/tdir-set-heading-property ()
  "Set :tangle-dir: for the current heading to (tdir-base \"SLUG\").
SLUG is derived from the heading title and confirmed in the minibuffer."
  (interactive)
  (let* ((title (substring-no-properties (org-entry-get nil "ITEM")))
         (slug  (thread-last title
                  (downcase)
                  (replace-regexp-in-string "[[:space:]]+" "-")
                  (replace-regexp-in-string "[^a-z0-9_-]" "")
                  (replace-regexp-in-string "-+" "-")
                  (string-trim "-")))
         (slug  (read-string "Slug for tdir-base: " slug))
         (value (format "(tdir-base \"%s\")" slug)))
    (org-set-property "tangle-dir" value)
    (message "Set :tangle-dir: %s" value)))

(with-eval-after-load 'org
  (keymap-set org-mode-map "C-c C-x T" #'f/tdir-set-heading-property))
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
           (or ">>" "»"))))

  (defun f/org-babel-noweb-wrap-insert-chars ()
    "Insert \"«\" and \"»\" "
    (interactive)
    (insert "«»")
    (backward-char)))
(defun org-get-full-outline-path ()
  "Retrieve the full heading path of the current heading."
  (interactive)
  (let ((path (org-get-outline-path t t)))
    (if path
        (mapconcat 'identity path "/")
      ;; (message (concat "Killed current Org outline path: " (mapconcat 'identity path "/")))
      (message "Not in an Org mode heading"))))

(defun org-kill-full-outline-path ()
  "Adds the full heading path of the current heading to kill-ring.

Wrapper for `org-get-full-outline-path'."
  (interactive)
  (kill-new (org-get-full-outline-path)))
(defun random-string-g-to-z (n)
  "Generate N random characters from G to Z.

The reason for using G to Z is to differentiate from MD5/HEX
strings that use A-F and 0-9. Also this is meant for simple
\"ID-fication\" of certain components like creating anchor links.

Inefficient implementation; don't use for large N. Testing showed
a limit of 530, more than that and lisp nesting will overflow."

  (let* ((alpha "ghijklmnopqrstuvwxyz")
         (i (% (abs (random)) (length alpha))))
    (if (= 0 n) ""
      (concat (substring alpha i (1+ i))
              (random-string-g-to-z (1- n))))))
(defun org-babel-get-tangle-files-by-ext (&optional ext)
  "Returns a list of unique filenames to be tangled that end with the specified EXT.

If EXT is not provided, default to \".el\".

This function parses all code blocks in the current Org buffer, identifies
those that contain the `:tangle' header argument (inherited or directly) and
collects the tangle filenames of those that end with the specified EXT.

Note that for this `string-suffix-p' is used to search for an EXT in the
format `.EXT' (with a period) so if a period isn't provided it is added and
if it was it is kept.

Example:

(org-babel-get-tangle-files-by-ext \"el\")"
  (let ((tangle-files '())
        (tangle-files-ext (concat "." (if ext (string-trim-left ext "\\.")
                                        ".el"))))
    (org-element-map (org-element-parse-buffer) 'src-block
      (lambda (src-block)
        (let* ((info (org-babel-get-src-block-info t src-block))
               (header-args (nth 2 info))
               (tangle (cdr (assoc :tangle header-args))))
          (when (and tangle
                     (stringp tangle)
                     (string-suffix-p tangle-files-ext tangle t))
            (push tangle tangle-files)))))
    (delete-dups tangle-files)))
(defun add-lexical-binding-prop (file)
  "Add `lexical-binding: t' prop to FILE without disrupting open buffers."
  (let ((buffer (get-buffer (find-file-noselect file))))
    (with-current-buffer buffer
      (add-file-local-variable-prop-line 'lexical-binding t nil)
      (save-buffer))
    (unless (get-buffer-window buffer 'visible)
      (kill-buffer buffer))))

(defun org-babel-tangle-add-lexical-prop-to-el-tangled-files()
  (dolist (file (let ((source-list (org-babel-get-tangle-files-by-ext "el"))
                      (filter-list '(".dir-locals.el")))
                  (filter-list-any source-list filter-list)))
    (add-lexical-binding-prop file)))

(provide '11xx-org-functions)
