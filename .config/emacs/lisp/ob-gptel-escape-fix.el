;;; ob-gptel-escape-fix.el --- Escape Org syntax in ob-gptel fenced results -*- lexical-binding: t; -*-

;; Package-Requires: ((emacs "28.1") (gptel "0.9") (ob-gptel "0.1"))

;;; Commentary:

;; When ob-gptel inserts LLM responses into fenced result blocks
;; (#+begin_src org, #+begin_export html, :wrap blocks, etc.), lines
;; starting with `#+' or `*' break the enclosing block boundary.
;; This package advises the ob-gptel execution pipeline to apply
;; `org-escape-code-in-region' (comma-escaping) to the response
;; before insertion.
;;
;; Two advice functions are installed:
;;
;; 1. Around-advice on `gptel--convert-markdown->org' — escapes
;;    after markdown-to-org conversion (for :format org blocks).
;;
;; 2. Around-advice on `org-babel-execute:gptel' — temporarily
;;    advises `gptel-request' to wrap the :callback with an
;;    escaping layer (for all fenced result blocks).
;;
;; Usage:
;;   (require 'ob-gptel-escape-fix)
;;
;; Or with use-package:
;;   (use-package ob-gptel-escape-fix :after ob-gptel)

;;; Code:

(require 'cl-lib)
(require 'org-src)

(defgroup ob-gptel-escape nil
  "Escape Org syntax in ob-gptel fenced result blocks."
  :group 'org-babel
  :prefix "ob-gptel-escape-")

(defcustom ob-gptel-escape-enabled t
  "When non-nil, escape Org block delimiters in fenced ob-gptel results.
Set to nil to disable escaping globally."
  :type 'boolean
  :group 'ob-gptel-escape)

(defvar ob-gptel-escape--active-p nil
  "Non-nil during ob-gptel async callbacks requiring Org-syntax escaping.
Do not set this directly; it is `let'-bound by the injected callback.")

(defconst ob-gptel-escape--fenced-results-re
  "\\b\\(org\\|code\\|pp\\|html\\|latex\\)\\b"
  "Regexp matching `:results' format keywords that produce fenced blocks.
These formats cause org-babel to wrap results in #+begin/#+end pairs.")

(defun ob-gptel-escape--fenced-result-p (params)
  "Return non-nil when PARAMS will produce a fenced result block.
Fenced blocks are #+begin_...#+end_ wrappers that require
comma-escaping of interior lines starting with `#+' or `*'.

Covers: org, code, pp (all produce #+begin_src), html and latex
\(both produce #+begin_export), and any :wrap value."
  (let ((results (or (cdr (assoc :results params)) ""))
        (wrap    (cdr (assoc :wrap params))))
    (or
     ;; :wrap FOO → #+begin_FOO … #+end_FOO
     ;; Accept any truthy value; reject nil and explicit negations.
     (and wrap
          (not (member (format "%s" wrap) '("" "no" "nil" "none"))))
     ;; :results format keywords that produce fenced blocks
     (and (stringp results)
          (string-match-p ob-gptel-escape--fenced-results-re results)))))

(defun ob-gptel-escape--escape-string (text)
  "Return TEXT with Org block delimiters comma-escaped.
Uses `org-escape-code-in-region' which prefixes lines starting
with `#+' or `*' with a comma, preventing them from breaking
enclosing #+begin/#+end blocks."
  (if (or (null text) (string-empty-p text))
      text
    (with-temp-buffer
      (insert text)
      (org-escape-code-in-region (point-min) (point-max))
      (buffer-string))))

(defun ob-gptel-escape--convert-markdown->org-a (orig-fn text)
  "Around-advice on `gptel--convert-markdown->org'.
When `ob-gptel-escape--active-p' is non-nil, applies Org block
delimiter escaping to the converted result.

ORIG-FN is the original function.  TEXT is the markdown input."
  (let ((result (funcall orig-fn text)))
    (if ob-gptel-escape--active-p
        (ob-gptel-escape--escape-string result)
      result)))

(defun ob-gptel-escape--make-callback (fmt orig-cb)
  "Return a callback wrapping ORIG-CB with Org-syntax escaping.
FMT is the :format header arg value from the source block.

When FMT is \"org\", escaping is deferred to the around-advice on
`gptel--convert-markdown->org' (which runs inside ORIG-CB).
For other formats, the raw response is escaped here before
ORIG-CB receives it.

Uses `apply-partially' to capture FMT and ORIG-CB as concrete
values, ensuring correct behavior regardless of the caller's
lexical-binding setting."
  (apply-partially
   (lambda (captured-fmt captured-orig-cb response info)
     (let ((ob-gptel-escape--active-p t)
           (safe-response response))
       ;; For non-org :format, gptel--convert-markdown->org is never
       ;; called inside captured-orig-cb, so escape the raw response
       ;; here.  For :format org, the conversion advice handles it;
       ;; skip to avoid double-escaping.
       (when (and (stringp response)
                  (not (equal captured-fmt "org")))
         (setq safe-response
               (ob-gptel-escape--escape-string
                (string-trim response))))
       (funcall captured-orig-cb safe-response info)))
   fmt orig-cb))

(defvar ob-gptel-escape--current-fmt nil
  "The :format value for the currently executing ob-gptel block.
Set by `ob-gptel-escape--org-babel-execute-a', read by the
temporary advice on `gptel-request'.  Non-nil only during the
synchronous phase of `org-babel-execute:gptel'.")

(defun ob-gptel-escape--gptel-request-a (orig-fn prompt &rest req-args)
  "Temporary around-advice on `gptel-request' for callback wrapping.
Installed and removed by `ob-gptel-escape--org-babel-execute-a'
within an `unwind-protect' to guarantee cleanup.

ORIG-FN is the original `gptel-request'.  PROMPT and REQ-ARGS
are passed through after wrapping the :callback."
  (let ((orig-cb (plist-get req-args :callback)))
    (when orig-cb
      (setq req-args
            (plist-put (copy-sequence req-args)
                       :callback
                       (ob-gptel-escape--make-callback
                        ob-gptel-escape--current-fmt orig-cb))))
    (apply orig-fn prompt req-args)))

(defun ob-gptel-escape--org-babel-execute-a (orig-fn body params)
  "Around-advice for `org-babel-execute:gptel'.
When the result will be placed in a fenced block and
`ob-gptel-escape-enabled' is non-nil, temporarily advises
`gptel-request' to wrap its :callback with an escaping layer.

Uses `advice-add'/`advice-remove' with `unwind-protect' instead
of `cl-letf' to avoid replacing the symbol-function slot, which
can trigger spurious redisplay errors from mode-line expressions
that reference gptel internals.

ORIG-FN is the original function.  BODY is the source block content.
PARAMS is the header argument alist."
  (if (or (not ob-gptel-escape-enabled)
          (not (ob-gptel-escape--fenced-result-p params)))
      (funcall orig-fn body params)
    (let ((ob-gptel-escape--current-fmt
           (or (cdr (assoc :format params))
               ;; Fall back to ob-gptel's own default rather than
               ;; hardcoding — respects user customization.
               (cdr (assoc :format org-babel-default-header-args:gptel))
               "org")))
      (advice-add 'gptel-request :around
                  #'ob-gptel-escape--gptel-request-a)
      (unwind-protect
          (funcall orig-fn body params)
        (advice-remove 'gptel-request
                       #'ob-gptel-escape--gptel-request-a)))))

;;;###autoload
(define-minor-mode ob-gptel-escape-mode
  "Toggle Org-syntax escaping for ob-gptel fenced result blocks.
When enabled, LLM responses inserted into fenced result blocks
\(#+begin_src org, #+begin_export, :wrap, etc.) have their Org
block delimiters comma-escaped to prevent breaking the enclosing
block.

This installs around-advice on `gptel--convert-markdown->org' and
`org-babel-execute:gptel'.  Disabling the mode removes both."
  :global t
  :group 'ob-gptel-escape
  (if ob-gptel-escape-mode
      (progn
        (setq ob-gptel-escape-enabled t)
        (advice-add 'gptel--convert-markdown->org :around
                    #'ob-gptel-escape--convert-markdown->org-a)
        (advice-add 'org-babel-execute:gptel :around
                    #'ob-gptel-escape--org-babel-execute-a))
    (setq ob-gptel-escape-enabled nil)
    (advice-remove 'gptel--convert-markdown->org
                   #'ob-gptel-escape--convert-markdown->org-a)
    (advice-remove 'org-babel-execute:gptel
                   #'ob-gptel-escape--org-babel-execute-a)))

;; Auto-activate when loaded after ob-gptel.
(with-eval-after-load 'ob-gptel
  (add-hook 'gptel-mode-hook #'ob-gptel-escape-mode))

(provide 'ob-gptel-escape-fix)
;;; ob-gptel-escape-fix.el ends here
