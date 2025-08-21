;; -*- lexical-binding: t; -*-
(defun f/mark-whole-word (&optional arg allow-extend)
  "Like `mark-word', but select whole words and skips over whitespace.
If you use a negative prefix ARG then select words backward.
Otherwise select them forward.

If cursor starts in the middle of word then select that whole word.

If there is whitespace between the initial cursor position and the
first word (in the selection direction), it is skipped (not selected).

If the command is repeated or the mark is active, select the next NUM
words, where NUM is the numeric prefix argument ARG.  (Negative NUM
selects backward.)

If second argument ALLOW-EXTEND is nil don't expand selection across words.
See `mark-word' for more."
  (interactive "P\np")
  (let ((num  (prefix-numeric-value arg)))
    (unless (eq last-command this-command)
      (if (natnump num)
          (skip-syntax-forward "\\s-")
        (skip-syntax-backward "\\s-")))
    (unless (or (eq last-command this-command)
                (if (natnump num)
                    (looking-at "\\b")
                  (looking-back "\\b")))
      (if (natnump num)
          (left-word)
        (right-word)))
    (mark-word arg allow-extend)))
(defun f/infer-indentation-style ()
  "Compare number of spaces and tabs and define `indent-tabs-mode' to t or nil.

If the current buffer or file has more tabs than spaces,
set `indent-tabs-mode' to t; if it has more spaces than tabs, set it to nil;
and if inconclusive, use current `indent-tabs-mode'."
  (interactive)
  (let ((space-count (how-many "^  " (point-min) (point-max)))
        (tab-count (how-many "^\t" (point-min) (point-max))))
    (if (> space-count tab-count) (setq indent-tabs-mode nil))
    (if (> tab-count space-count) (setq indent-tabs-mode t))))
(add-hook 'prog-mode-hook #'f/infer-indentation-style)
(defun f/current-timestamp-format ()
  "Return current timestamp and hostname in a formatted string."
  (concat "[" (format-time-string "%Y-%m-%d %a %H:%M:%S %Z" (current-time)) "] @" (system-name)))

;;;###autoload
(defun f/current-timestamp-insert ()
  "Insert the current timestamp and hostname in a formatted string as a comment."
  (interactive)
  (let ((str (f/current-timestamp-format))
        (start-point (point)))
    (insert str)
    (set-mark start-point)
    (comment-region (region-beginning) (region-end))))
;; [2024-08-28 Wed 03:14:39 -03] @ak
;; # [2023-12-10 Sun 01:33:12 -03:00] @winr58
(defun f/kill-matching-lines (regexp &optional rstart rend interactive)
  "Kill lines containing matches for REGEXP.

Second and third arg RSTART and REND specify the region to operate on.
When calling this function from Lisp, you can pretend that it was
called interactively by passing a non-nil INTERACTIVE argument.
See `flush-lines' or `keep-lines' for behavior of this command.

If the buffer is read-only, Emacs will beep and refrain from deleting
the line, but put the line in the kill ring anyway.  This means that
you can use this command to copy text from a read-only buffer.
\(If the variable `kill-read-only-ok' is non-nil, then this won't
even beep.)"
  (interactive
   (keep-lines-read-args "Kill lines containing match for regexp"))
  (let ((buffer-file-name nil)) ;; HACK for `clone-buffer'
    (with-current-buffer (clone-buffer nil nil)
      (let ((inhibit-read-only t))
        (keep-lines regexp rstart rend interactive)
        (kill-region (or rstart (line-beginning-position))
                     (or rend (point-max))))
      (kill-buffer)))
  (unless (and buffer-read-only kill-read-only-ok)
    ;; Delete lines or make the "Buffer is read-only" error.
    (flush-lines regexp rstart rend interactive)))
(defun f/check-make-directory (dir)
  "Check if DIR exists and create it if it doesn't.

It uses `make-directory' PARENTS argument 't'."
  (if (not (file-exists-p dir))
      (make-directory dir t)))
(defun xdg-bin-home ()
  "Return the base directory for user specific executable files."
  (xdg--dir-home "XDG_BIN_HOME" "~/.local/bin"))
(defun xdg-state-home ()
  "Return the base directory for user specific log files."
  (xdg--dir-home "XDG_STATE_HOME" "~/.local/state"))
(defun f/read-file-contents (file-path)
  "Read the contents of the file at FILE-PATH and return it as a string."
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))
    ;;; Stefan Monnier <foo at acm.org>. It is the opposite of fill-paragraph
(defun unfill-paragraph (&optional region)
  "Takes a multi-line paragraph and makes it into a single line of text."
  (interactive (progn (barf-if-buffer-read-only) '(t)))
  (let ((fill-column (point-max))
        ;; This would override `fill-column' if it's an integer.
        (emacs-lisp-docstring-fill-column t))
    (fill-paragraph nil region)))

;; Handy key definition
(define-key global-map "\M-Q" 'unfill-paragraph)
(defun filter-list-any (source-list filter-list)
  "Filter out items from SOURCE-LIST that are found in FILTER-LIST."
  (let ((hash-table (make-hash-table :test 'equal))
        result)
    ;; Populate the hash table with elements from the filter list
    (dolist (item filter-list)
      (puthash item t hash-table))
    ;; Build the result list by filtering out items in the hash table
    (dolist (item source-list)
      (unless (gethash item hash-table)
        (push item result)))
    ;; The result list is built in reverse order, so reverse it
    (nreverse result)))
(defun filter-list-any-string-prefix (source-list filter-list)
  "Filter out items from SOURCE-LIST that match any prefix in FILTER-LIST.

Example:

   (filter-list-any-string-prefix
     '(\"--fruit=banana\" \"orange\" \"cherry\" \"--veggie=potato\")
     '(\"--fruit\" \"--veggie\"))
   => '(\"orange\" \"cherry\")"
  (let (result)
    (dolist (item source-list)
      (unless (seq-some
               (lambda (prefix)
                 (string-prefix-p prefix item))
               filter-list)
        (push item result)))
    (nreverse result)))
(defmacro with-system (type &rest body)
  "Evaluate BODY if `system-type' equals TYPE."
  (declare (indent defun))
  `(when (eq system-type ',type)
     ,@body))
(cl-defun add-or-replace-to-alist (list-var element &key append prepend)
  "Add or replace ELEMENT or a list of ELEMENTS in the alist stored in LIST-VAR.

LIST-VAR should be a symbol whose value is a proper alist.
ELEMENT may be a single alist entry (a list or cons whose CAR is the lookup key)
or a list of such entries.  If multiple entries are given, each is merged
individually rather than nesting.

By default, new entries are prepended.  Use :append to add at the end,
or :prepend to force prepending (it overrides :append).

Returns the updated alist value (like 'add-to-list').  Also echoes a
message indicating how many entries were added or replaced.

Arguments:
  LIST-VAR   Symbol naming the target alist variable.
  ELEMENT    A single entry (list or cons) or a list of entries.
  ':append'   If non-nil, append new entries.
  `:prepend'  If non-nil, prepend new entries.

Examples:
    ;; Single entry - replaces if key exists, adds if not
    (setq servers '((\"prod\" . \"192.168.1.10\") (\"dev\" . \"192.168.1.20\")))
    (add-or-replace-to-alist 'servers '(\"prod\" . \"10.0.0.100\"))
    ;; => ((\"prod\" . \"10.0.0.100\") (\"dev\" . \"192.168.1.20\"))

    ;; Multiple entries with :append
    (add-or-replace-to-alist
    'auto-mode-alist
    '((\"\\.tsx\\'\" . typescript-mode)
    (\"\\.vue\\'\" . vue-mode))
    :append t)"
  (let ((count 0)
        updated)
    ;; Handle a list of entries recursively
    (cl-labels ((process-entry (entry)
                  (let* ((key   (car entry))
                         (alist (symbol-value list-var))
                         (found (assoc key alist)))
                    ;; remove any old entry
                    (setq alist (cl-remove-if (lambda (old)
                                                (equal (car old) key))
                                              alist))
                    ;; insert
                    (setq alist
                          (cond
                           (prepend  (cons entry alist))
                           (append   (append alist (list entry)))
                           (t        (cons entry alist))))
                    ;; update var, bump counter
                    (set list-var alist)
                    (cl-incf count)
                    alist)))
      (if (and (listp element)
               element
               (cl-every (lambda (e) (and (listp e)
                                          (not (keywordp (car e)))))
                         element))
          (dolist (e element)
            (setq updated (process-entry e)))
        (setq updated (process-entry element))))
    (message "add-or-replace-to-alist: %d entr%s %s"
             count
             (if (> count 1) "ies were" "y was")
             (if append "appended/replaced." "prepended/replaced."))
    updated))

(provide '11xx-functions)
