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

  (defun org-babel-noweb-wrap-insert-chars ()
    "Insert « and »." 
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
