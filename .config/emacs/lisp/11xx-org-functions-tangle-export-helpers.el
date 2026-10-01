;;; 11xx-org-functions-tangle-export-helpers.el --- Org babel tangle/export helpers  -*- lexical-binding: t; -*-

;;; Code:
;;;###autoload
(defun org-babel-get-src-block-header-arg (header-arg)
  "Get the value of the header argument HEADER-ARG from the provided SRC-BLOCK-INFO.

First argument `org-babel-get-src-block-info' is set to `t'
because it will try to evaluate function in e.g. `:tangle' and if
for some reason that function refers to
`org-babel-get-src-block-info' it infinite loops."
  ;; This could be set as an optional arg? but then what's the point meh haha
  (let* ((src-block-info (org-babel-get-src-block-info t)) ; t for NO-EVAL, otherwise it will infinite loop
         (params (nth 2 src-block-info)))
    (assoc-default header-arg params)))

;;;###autoload
(defun darkmandir (shfile)
  "Evaluate to a filename in a directory from `XDG_DATA_HOME' that's either `light-mode.d' or `dark-mode.d'.

The string argument SHFILE is the target filename of the darkman script to be tangled.

Usage:
  Either set
  A header-arg \":theme light\" or \":theme dark\";
  A `org-set-property' called 'theme' with value \"dark\" or \"light\".

  Then using the function returns:
  (darkmandir \"script.sh\")
    => \"/home/user/.local/share/light-mode.d/script.sh\"
    or
    => \"/home/user/.local/share/dark-mode.d/script.sh\""
  (let* ((file (if shfile (string-trim shfile "/")))
         (dir-light (expand-file-name "light-mode.d/" (xdg-data-home)))
         (dir-dark (expand-file-name "dark-mode.d/" (xdg-data-home)))
         (out-path-light (expand-file-name file dir-light))
         (out-path-dark (expand-file-name file dir-dark)))
    (cond
     ((or (string= (org-babel-get-src-block-header-arg :theme) "light")
          (string= (org-entry-get nil "theme" t) "light"))
      out-path-light)
     ((or (string= (org-babel-get-src-block-header-arg :theme) "dark")
          (string= (org-entry-get nil "theme" t) "dark"))
      out-path-dark))))

;;;###autoload
(defun vault-value (name)
  "Return the trimmed contents of the vault value NAME."
  (let ((root (or (getenv "VAULT_HOME") "~/.local/vault")))
    (with-temp-buffer
      (insert-file-contents (expand-file-name (concat "conf/" name) root))
      (string-trim (buffer-string)))))

(provide '11xx-org-functions-tangle-export-helpers)
;;; 11xx-org-functions-tangle-export-helpers.el ends here
