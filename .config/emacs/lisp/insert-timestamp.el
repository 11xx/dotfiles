;;; insert-timestamp.el --- Small timestamp insertion helpers -*- lexical-binding: t; -*-

(defun current-timestamp--hostname-suffix ()
  "Return hostname suffix used by timestamp insertion commands."
  (concat " @" (system-name)))

(defun current-timestamp-org ()
  "Return current timestamp in Org-friendly human-readable format."
  (format-time-string "%Y-%m-%d %a %H:%M:%S %Z"))

(defun current-timestamp-iso-basic ()
  "Return current UTC timestamp in ISO 8601 basic format.

This is compact and alphanumeric-only, for example:

  20260522T183045Z"
  (format-time-string "%Y%m%dT%H%M%SZ" nil t))

(defun current-timestamp-iso ()
  "Return current timestamp in ISO 8601 / RFC 3339-style extended format.

This contains no spaces, for example:

  2026-05-22T15:30:45-03:00"
  (let ((ts (format-time-string "%Y-%m-%dT%H:%M:%S%z")))
    (replace-regexp-in-string
     "\\([+-][0-9][0-9]\\)\\([0-9][0-9]\\)\\'"
     "\\1:\\2"
     ts)))

(defun current-timestamp-comment-format ()
  "Return current timestamp and hostname in comment-marker format.

This is intended for code timestamp marks with readable metadata, for example:

  [2026-05-22 Fri 15:30:45 -03] @hostname"
  (concat "["
          (format-time-string "%Y-%m-%d %a %H:%M:%S %Z")
          "]"
          (current-timestamp--hostname-suffix)))

;; Backward-compatible alias for the old frequently-used name.
(defalias 'current-timestamp-format #'current-timestamp-comment-format)

(defun current-timestamp--insert-as-comment (str)
  "Insert STR and comment it using the current major mode's syntax."
  (let ((start-point (point)))
    (insert str)
    (comment-region start-point (point))))

;;;###autoload
(defun current-timestamp-insert-comment ()
  "Insert the current comment-marker timestamp and hostname as a comment."
  (interactive)
  (current-timestamp--insert-as-comment
   (current-timestamp-comment-format)))

;; Backward-compatible alias for the old frequently-used command.
(defalias 'current-timestamp-insert #'current-timestamp-insert-comment)

;;;###autoload
(defun current-timestamp-insert-org ()
  "Insert current Org-friendly timestamp followed by hostname."
  (interactive)
  (insert (current-timestamp-org)
          (current-timestamp--hostname-suffix)))

;;;###autoload
(defun current-timestamp-insert-iso-basic ()
  "Insert current ISO 8601 basic UTC timestamp followed by hostname.

The timestamp itself is alphanumeric-only."
  (interactive)
  (insert (current-timestamp-iso-basic)
          (current-timestamp--hostname-suffix)))

;;;###autoload
(defun current-timestamp-insert-iso ()
  "Insert current ISO 8601 / RFC 3339-style timestamp followed by hostname.

The timestamp contains no spaces."
  (interactive)
  (insert (current-timestamp-iso)
          (current-timestamp--hostname-suffix)))

(provide 'insert-timestamp)
;;; insert-timestamp.el ends here
