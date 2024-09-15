((org-mode . ((eval . (defun add-lexical-binding-prop (file)
                        "Add `lexical-binding: t' prop to FILE without disrupting open buffers."
                        (let ((buffer (get-buffer (find-file-noselect file))))
                          (with-current-buffer buffer
                            (add-file-local-variable-prop-line 'lexical-binding t nil)
                            (save-buffer))
                          (unless (get-buffer-window buffer 'visible)
                            (kill-buffer buffer)))))

              (eval . (defun org-babel-get-tangle-files-by-ext (&optional ext)
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
                          (delete-dups tangle-files))))

              (eval . (defun f/tangle-lex-prop()
                        (dolist (file (let ((source-list (org-babel-get-tangle-files-by-ext "el"))
                                            (filter-list '(".dir-locals.el")))
                                        (filter-list-with-hash-table source-list filter-list)))
                          (add-lexical-binding-prop file))))

              ;; from chatgpt: function for filtering items from a list using a list
              (eval . (defun filter-list-with-hash-table (source-list filter-list)
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
                          (nreverse result)))))))
