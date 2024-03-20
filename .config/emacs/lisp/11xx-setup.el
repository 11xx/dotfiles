;; -*- lexical-binding: t; -*-
;; (require '11xx-package)

(eval-when-compile
  (when after-init-time
    (package-initialize))
  (require 'setup nil t))

(unless (package-installed-p 'setup)
  (package-install 'setup))
(defun my-protect-setup (expansion)
  "Wrap `setup' output with `condition-case'."
  (let ((err (gensym "setup-err")))
    `(condition-case ,err
   ,expansion
       (error
  (display-warning 'setup (concat "Problem in config: "
          (error-message-string ,err)
          ": \n"
          (with-output-to-string
                                          (pp (quote ,expansion))))
                         :error)))))

(advice-add 'setup :filter-return #'my-protect-setup)
(setup-define :package
  (lambda (package)
    (if (consp package)
        `(unless (and (package-installed-p ',(car package))
                      (package-vc-p (cadr (assoc ',(car package)
                                                 (package--alist)))))
           (package-vc-install
            ,(if (consp (cdr package))
                 `',(car package)
               `(list ',(car package) ,@(cdr package)))))
      `(unless (package-installed-p ',package)
         (unless (memq ',package package-archive-contents)
           (package-refresh-contents))
         (package-install ',package))))
  :documentation "Install PACKAGE if it hasn't been installed yet.
The first PACKAGE can be used to deduce the feature context.  If
PACKAGE is a cons-cell, then the it will be interpreted as a
package specification that will be passed to
`package-vc-install'."
  :repeatable t
  :shorthand (lambda (form)
               (if (consp (cadr form)) (caadr form) (cadr form))))
(setup-define :local-or-package
  (lambda (feature-or-package)
    `(unless (locate-file ,(symbol-name feature-or-package)
                          load-path
                          (get-load-suffixes))
       (:package ,feature-or-package)))
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

(provide '11xx-setup)
