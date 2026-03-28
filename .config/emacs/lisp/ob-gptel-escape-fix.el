;;; ob-gptel-escape-fix.el --- Escape Org syntax in ob-gptel results -*- lexical-binding: t; -*-

(defvar ob-gptel-escape--active-p nil
  "Non-nil during `ob-gptel' async callbacks requiring Org-syntax escaping.")

(defun ob-gptel-escape--convert-markdown->org-a (orig-fn text)
  "Advise `gptel--convert-markdown->org' to escape Org block syntax.
ORIG-FN is the original conversion function. TEXT is the input string."
  (let ((result (funcall orig-fn text)))
    (if ob-gptel-escape--active-p
        (with-temp-buffer
          (insert result)
          (org-escape-code-in-region (point-min) (point-max))
          (buffer-string))
      result)))

(defun ob-gptel-escape--org-babel-execute-a (orig-fn body params)
  "Advise `org-babel-execute:gptel' to apply Org-syntax escaping.
ORIG-FN is the original execution function. BODY is the source block content.
PARAMS is the association list of header arguments."
  (let* ((results (cdr (assoc :results params)))
         (needs-escape (and (stringp results)
                            (string-match-p "\\borg\\b" results))))
    (if (not needs-escape)
        (funcall orig-fn body params)
      (let ((orig-req (symbol-function 'gptel-request))
            (fmt (or (cdr (assoc :format params)) "org")))
        (cl-letf (((symbol-function 'gptel-request)
                   (lambda (prompt &rest req-args)
                     (let ((orig-cb (plist-get req-args :callback)))
                       (when orig-cb
                         ;; Copy the plist to avoid mutating shared lists,
                         ;; then safely replace the callback.
                         (setq req-args
                               (plist-put
                                (copy-sequence req-args)
                                :callback
                                (apply-partially
                                 (lambda (captured-fmt captured-orig-cb response info)
                                   (let ((ob-gptel-escape--active-p t)
                                         (safe-response response))
                                     ;; Handle non-org formats where conversion is bypassed
                                     (when (and (stringp response)
                                                (not (equal captured-fmt "org")))
                                       (setq safe-response
                                             (with-temp-buffer
                                               (insert (string-trim response))
                                               (org-escape-code-in-region (point-min) (point-max))
                                               (buffer-string))))
                                     (funcall captured-orig-cb safe-response info)))
                                 fmt orig-cb))))
                       (apply orig-req prompt req-args)))))
          (funcall orig-fn body params))))))

(with-eval-after-load 'ob-gptel
  (advice-add 'gptel--convert-markdown->org :around
              #'ob-gptel-escape--convert-markdown->org-a)
  (advice-add 'org-babel-execute:gptel :around
              #'ob-gptel-escape--org-babel-execute-a))

(provide 'ob-gptel-escape-fix)
;;; ob-gptel-escape-fix.el ends here
