;;; ob-gptel-escape-fix.el --- Escape Org syntax in ob-gptel fenced results -*- lexical-binding: t; -*-

;; (require 'ob-gptel)
;; (require 'org-src)
;; (require 'cl-lib)

(defvar ob-gptel-escape--active-p nil
  "Non-nil during `ob-gptel' async callbacks requiring Org-syntax escaping.")

(defun ob-gptel-escape--fenced-result-p (params)
  "Return non-nil when PARAMS will produce a fenced result block.
Fenced blocks are any #+begin_...#+end_ wrappers: org, code, pp,
html, latex, and any :wrap value.  These require comma-escaping of
lines starting with #+ to prevent premature block termination."
  (let ((results (or (cdr (assoc :results params)) ""))
        (wrap    (cdr (assoc :wrap params))))
    (or
     ;; :wrap FOO → #+begin_FOO … #+end_FOO (any non-empty, non-disabled value)
     (and (stringp wrap)
          (not (member wrap '("" "no" "nil"))))
     ;; Format keywords that produce fenced blocks
     (string-match-p
      "\\b\\(org\\|code\\|pp\\|html\\|latex\\)\\b"
      results))))

(defun ob-gptel-escape--convert-markdown->org-a (orig-fn text)
  "Around-advice on `gptel--convert-markdown->org'.
When `ob-gptel-escape--active-p' is non-nil, applies
`org-escape-code-in-region' to the converted result.
ORIG-FN is the original function. TEXT is the markdown input."
  (let ((result (funcall orig-fn text)))
    (if ob-gptel-escape--active-p
        (with-temp-buffer
          (insert result)
          (org-escape-code-in-region (point-min) (point-max))
          (buffer-string))
      result)))

(defun ob-gptel-escape--org-babel-execute-a (orig-fn body params)
  "Around-advice for `org-babel-execute:gptel'.
When result will be placed in a fenced block, wraps the
`gptel-request' :callback to apply Org-syntax escaping.
ORIG-FN is the original function. BODY is the block content.
PARAMS is the header argument alist."
  (if (not (ob-gptel-escape--fenced-result-p params))
      (funcall orig-fn body params)
    (let ((orig-req (symbol-function 'gptel-request))
          (fmt      (or (cdr (assoc :format params)) "org")))
      (cl-letf (((symbol-function 'gptel-request)
                 (lambda (prompt &rest req-args)
                   (let ((orig-cb (plist-get req-args :callback)))
                     (when orig-cb
                       (setq req-args
                             (plist-put
                              (copy-sequence req-args)
                              :callback
                              (apply-partially
                               (lambda (captured-fmt captured-orig-cb response info)
                                 (let ((ob-gptel-escape--active-p t)
                                       (safe-response response))
                                   ;; :format org path: gptel--convert-markdown->org
                                   ;; runs inside captured-orig-cb and the advice
                                   ;; above handles escaping via ob-gptel-escape--active-p.
                                   ;; :format markdown (or other) path: no conversion
                                   ;; runs, so escape the raw response here instead.
                                   (when (and (stringp response)
                                              (not (equal captured-fmt "org")))
                                     (setq safe-response
                                           (with-temp-buffer
                                             (insert (string-trim response))
                                             (org-escape-code-in-region
                                              (point-min) (point-max))
                                             (buffer-string))))
                                   (funcall captured-orig-cb safe-response info)))
                               fmt orig-cb))))
                     (apply orig-req prompt req-args)))))
        (funcall orig-fn body params)))))

(with-eval-after-load 'ob-gptel
  (advice-add 'gptel--convert-markdown->org :around
              #'ob-gptel-escape--convert-markdown->org-a)
  (advice-add 'org-babel-execute:gptel :around
              #'ob-gptel-escape--org-babel-execute-a))

(provide 'ob-gptel-escape-fix)
;;; ob-gptel-escape-fix.el ends here
