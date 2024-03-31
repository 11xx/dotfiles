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
(defun org-custom-id--create ()
  "Create and store CUSTOM_ID for current heading path."
  (let ((id (concat "orgid-" (random-string-g-z 6))))
    (org-entry-put nil "CUSTOM_ID" id)
    (org-id-add-location id (buffer-file-name (buffer-base-buffer)))
    id))

(defun org-custom-id--get-create (&optional force where)
  "Get or create CUSTOM_ID for heading at WHERE.

If FORCE is t, always recreate the property."
  (org-with-point-at where
    (let ((old-id (org-entry-get nil "CUSTOM_ID")))
      ;; If CUSTOM_ID exists and FORCE is false, return it
      (if (and (not force) old-id (stringp old-id))
          (progn
            (org-id-add-location old-id
                                 (buffer-file-name (buffer-base-buffer)))
            old-id)
        ;; otherwise, create it
        (org-custom-id--create)))))

(defun org-custom-id (&optional arg)
  "Get or create CUSTOM_ID for heading at point.

If a `\\[universal-argument]' prefix is present FORCE is set to t."
  (interactive "P")
  (let ((force (not (null current-prefix-arg))))  ;; Check if C-u prefix is used
    (org-custom-id--get-create force nil))
  (org-store-link nil t))

(keymap-global-set "C-c o i" #'org-custom-id)
(defun random-string-g-z (n)
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
              (random-string-g-z (1- n))))))

(provide '11xx-org-functions)
