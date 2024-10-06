;; -*- lexical-binding: t; -*-
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(defvar elpaca-installer-version 0.7)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (< emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                 ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                 ,@(when-let ((depth (plist-get order :depth)))
                                                     (list (format "--depth=%d" depth) "--no-single-branch"))
                                                 ,(plist-get order :repo) ,repo))))
                 ((zerop (call-process "git" nil buffer t "checkout"
                                       (or (plist-get order :ref) "--"))))
                 (emacs (concat invocation-directory invocation-name))
                 ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                       "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                 ((require 'elpaca))
                 ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (load "./elpaca-autoloads")))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

(elpaca setup (require 'setup))
(elpaca-wait)

(defun setup-config-error-into-warning (expansion)
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

(advice-add 'setup :filter-return #'setup-config-error-into-warning)

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

(elpaca no-littering (require 'no-littering))
(elpaca-wait)

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "eln-cache" no-littering-var-directory))))

(add-to-list 'native-comp-eln-load-path
             (convert-standard-filename
              (expand-file-name "eln-cache" no-littering-var-directory)))

(require '11xx-functions)

(defvar v/backup-directory
  (expand-file-name "backups"
                    (expand-file-name "var" user-emacs-directory))
  "Custom backup-files directory.")

;; Auto-save directory variable
(defvar v/auto-save-directory
  (expand-file-name "auto-save"
                    (expand-file-name "var" user-emacs-directory))
  "Custom auto-save files directory.")

(f/check-make-directory v/backup-directory)
(f/check-make-directory v/auto-save-directory)

;; ;; add random number to auto save file list
;; (defun f/auto-save-list-file-name-function ()
;;   (let ((basename (concat v/auto-save-directory "/auto-save-list-"))
;;         (random-number (number-to-string (random))))
;;     (concat basename (substring random-number 0 8) "~")))
;; (setq auto-save-list-file-name-function #'f/auto-save-list-file-name-function)

(setopt backup-directory-alist `((".*" . ,v/backup-directory))
        auto-save-file-name-transforms `(("\\(?:[^/]*/\\)*\\(.*\\)" ,(concat v/auto-save-directory "\\\\1") t))
        auto-save-list-file-prefix v/auto-save-directory
        auto-save-list-file-name (concat v/auto-save-directory "/auto-save-list")
        make-backup-files t    ; backup of a file the first time it is saved.
        backup-by-copying t    ; don't clobber symlinks
        version-control t      ; version numbers for backup files
        delete-old-versions t  ; delete excess backup files silently
        kept-old-versions 6    ; oldest versions to keep when a new numbered backup is made (default: 2)
        kept-new-versions 9    ; newest versions to keep when a new numbered backup is made (default: 2)
        auto-save-default t    ; auto-save every buffer that visits a file
        auto-save-timeout 1   ; number of seconds idle time before auto-save (default: 30)
        auto-save-interval 200) ; number of keystrokes between auto-saves (default: 300)

(setopt create-lockfiles nil)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(setq gc-cons-threshold (* 1000 8 2 100)) ; (* 1000 8) (8KB) is the default
(add-hook 'elpaca-after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

(require 'utf-8-default)
(require '11xx-defaults)
(require '11xx-completion)
(require '11xx-ui)
(require '11xx-navigation)
(require '11xx-half-scroll)
(require '11xx-pixel-scroll)
(require '11xx-dired)
(require '11xx-magit)
(require '11xx-org)
(require '11xx-modes)
