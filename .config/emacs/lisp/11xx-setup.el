;; -*- lexical-binding: t; -*-
(elpaca setup (require 'setup))
(elpaca-wait)
(defmacro setup-elpaca (order &rest body)
  "Execute BODY in `setup' declaration after ORDER is finished.
If the :disabled keyword is present in body, the package is completely ignored.
This happens regardless of the value associated with :disabled.
The expansion is a string indicating the package has been disabled."
  (declare (indent 1))
  (if (memq :disabled body)
      (format "%S :disabled by -setup" order)
    (let ((o order))
      (when-let ((ensure (cl-position :ensure body)))
        (setq o (if (null (nth (1+ ensure) body)) nil order)
              body (append (cl-subseq body 0 ensure)
                           (cl-subseq body (+ ensure 2)))))
      `(elpaca ,o (setup
                      ,(if-let (((memq (car-safe order) '(quote \`)))
                                (feature (flatten-tree order)))
                           (cadr feature)
                         (elpaca--first order))
                    ,@body)))))
(defun setup-wrap-to-install-package (body _name)
  "Wrap BODY in an `elpaca' block if necessary.
The body is wrapped in an `elpaca' block if `setup-attributes'
contains an alist with the key `elpaca'."
  (if (assq 'elpaca setup-attributes)
      `(elpaca ,(cdr (assq 'elpaca setup-attributes)) ,@(macroexp-unprogn body))
    body))

;; Add the wrapper function
(add-to-list 'setup-modifier-list #'setup-wrap-to-install-package)

(setup-define :elpaca
  (lambda (order &rest recipe)
    (push (cond
           ((eq order t) `(elpaca . ,(setup-get 'feature)))
           ((eq order nil) '(elpaca . nil))
           (`(elpaca . (,order ,@recipe))))
          setup-attributes)
    ;; If the macro wouldn't return nil, it would try to insert the result of
    ;; `push' which is the new value of the modified list. As this value usually
    ;; cannot be evaluated, it is better to return nil which the byte compiler
    ;; would optimize away anyway.
    nil)
  :documentation "Install ORDER with `elpaca'.
The ORDER can be used to deduce the feature context."
  :shorthand #'cadr)
(setup-define :local-or-package
  (lambda (feature-or-package)
    `(unless (locate-file ,(symbol-name feature-or-package)
                          load-path
                          (get-load-suffixes))
       (:elpaca ,feature-or-package)))
  :documentation "Install PACKAGE if it is not available locally.
This macro can be used as NAME, and it will replace itself with
the first PACKAGE."
  :repeatable t
  :shorthand #'cadr)
(setup-define :disabled
  (lambda ()
    `,(setup-quit))
  :documentation "Always stop evaluating the body.")
(setup-define :advise
    (lambda (symbol where function)
      `(advice-add ',symbol ,where ,function))
  :documentation "Add a piece of advice on a function.
See `advice-add' for more details."
  :after-loaded t
  :debug '(sexp sexp function-form)
  :ensure '(nil nil func)
  :repeatable t)
(setup-define :load-after
  (lambda (&rest features)
    (let ((body `(require ',(setup-get 'feature))))
      (dolist (feature (nreverse features))
        (setq body `(with-eval-after-load ',feature ,body)))
      body))
  :documentation "Load the current feature after FEATURES.")
(setup-define :hide-mode
  (lambda (&optional mode)
    (let* ((mode (or mode (setup-get 'mode)))
           (mode (if (string-match-p "-mode\\'" (symbol-name mode))
                     mode
                   (intern (format "%s-mode" mode)))))
      `(setq minor-mode-alist
             (delq (assq ',mode minor-mode-alist)
                   minor-mode-alist))))
  :documentation "Hide the mode-line lighter of the current mode.
Alternatively, MODE can be specified manually, and override the
current mode."
  :after-loaded t)
(setup-define :put-enable
  (lambda (commands)
    `(put ',commands 'disabled nil))
  :documentation "Enable disabled COMMANDS."
  :after-loaded t
  :repeatable t)
(setup-define :face
  (lambda (face spec) `(custom-set-faces (quote (,face ,spec))))
  :documentation "Customize FACE to SPEC."
  :signature '(face spec ...)
  :debug '(setup)
  :repeatable t
  :after-loaded t)
(setup-define :autoload
  (lambda (func)
    (let ((fn (if (memq (car-safe func) '(quote function))
                  (cadr func)
                func)))
      `(unless (fboundp (quote ,fn))
         (autoload (function ,fn) ,(symbol-name (setup-get 'feature)) nil t))))
  :documentation "Autoload COMMAND if not already bound."
  :repeatable t
  :signature '(FUNC ...))
(setup-define :option*
  (lambda (name val)
    `(customize-set-variable
      ',(intern (format "%s-%s" (setup-get 'feature) name))
      ,val
      ,(format "Set for %s's setup block" (setup-get 'feature))))
  :documentation "Set the option NAME to VAL.
NAME is not the name of the option itself, but of the option with
the feature prefix."
  :debug '(sexp form)
  :repeatable t)

(provide '11xx-setup)
