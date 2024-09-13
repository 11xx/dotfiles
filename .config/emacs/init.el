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

;; (setup (:with-hook elpaca-after-init-hook
;;          (:hook (lambda()
;;                   (require '11xx-defaults)
;;                   (require '11xx-completion)
;;                   (require '11xx-ui)
;;                   (require '11xx-navigation)
;;                   (require '11xx-half-scroll)
;;                   (require '11xx-pixel-scroll)
;;                   (require '11xx-dired)
;;                   (require '11xx-magit)
;;                   (require '11xx-gc)
;;                   (require '11xx-org)
;;                   (require '11xx-modes)))))

(setup emacs
  ;; Keybindings
  (:global
   "C-c C-/"          comment-region
   "C-c C-M-/"        uncomment-region
   [remap mark-word]  f/mark-whole-word
   ;; Local file variables
   "C-c a f v"        add-file-local-variable
   "C-c d f v"        delete-file-local-variable
   "C-c a f p"        add-file-local-variable-prop-line
   "C-c d f p"        delete-file-local-variable-prop-line
   ;; Custom functions
   ;; Text display
   "C-c C-M-t"  visual-line-mode
   "C-c M-t"    toggle-truncate-lines
   ;; Insert text
   "C-c i t" f/current-timestamp-insert
   ;; UI Changes
   "C-c d c" visual-fill-column-mode
   "C-x C-z" org-set-property
   "C-z" org-set-property
   ;; [[https://www.emacswiki.org/emacs/WindowResize][EmacsWiki: Window Resize]] [2022-04-20 Wed 02:50:51]
   "S-C-<left>"   shrink-window-horizontally
   "S-C-<right>"  enlarge-window-horizontally
   "S-C-<down>"   shrink-window
   "S-C-<up>"     enlarge-window
   ;; Cursor
   "C-M-d" backward-delete-char ; was down-list
   "M-D"   backward-kill-word
   ;; "M-h"          backward-delete-char ; was `mark-paragraph' global
   ;; "M-H"          backward-kill-word ; was `mark-paragraph' global, separate override may be necessary for local maps
   "M-." forward-list
   "M-," backward-list
   "C-M-." down-list ; up-list
   "C-M-," backward-up-list
   )

  ;; Enable disabled 'advanced' commands
  (:put-enable narrow-to-region
               narrow-to-page
               narrow-to-defun
               widen
               downcase-region)

  (add-function :after after-focus-change-function
                (lambda() (save-some-buffers t)))

  ;;; Minor modes
  ;; (:also-load mouse)
  ;; (xterm-mouse-mode 1) ;; xterm mouse support
  (save-place-mode 1)
  (delete-selection-mode 1) ; delete marked region with backspace

  ;; #manual-smartparens
  (electric-pair-mode 1)
  (electric-indent-mode 1))

(setopt
 read-process-output-max (* 3 (* 1024 1024)) ;; 3M
 indent-tabs-mode nil ; disable tabs
 tab-width 2
 tab-stop-list (number-sequence 2 4 2) ; if `tab-width' in not read, use this
 tab-always-indent t ; when using the TAB key
 org-edit-src-content-indentation 0
 org-src-preserve-indentation nil  ; default is nil
 ;; inhibit-startup-echo-area-message "lobster"
 inhibit-startup-message 't
 ;; initial-major-mode 'fundamental-mode
 ;; initial-scratch-message 'nil
 undo-limit 1000000000
 undo-strong-limit 1000000000
 undo-outer-limit 1010000000
 ring-bell-function 'ignore
 auto-window-vscroll nil
 )

;; #manual-smartparens
;; (use-package smartparens
;;   :ensure t
;;   :init
;;   ;; [[https://xenodium.com/emacs-smartparens-auto-indent/][Emacs smartparens auto-indent]]
;;   ;; [[https://github.com/Fuco1/smartparens/issues/80][Newline and indent on appropriate pairs · Issue #80 · Fuco1/smartparens · GitHub]]
;;   (defun indent-between-pair (&rest _ignored)
;;     (newline)
;;     (indent-according-to-mode)
;;     (forward-line -1)
;;     (indent-according-to-mode))

;;   (sp-local-pair 'prog-mode "{" nil :post-handlers '((indent-between-pair "RET")))
;;   (sp-local-pair 'prog-mode "[" nil :post-handlers '((indent-between-pair "RET")))
;;   (sp-local-pair 'prog-mode "(" nil :post-handlers '((indent-between-pair "RET")))
;;   :config
;;   (smartparens-global-mode 1))
(setup whitespace
  (:hide-mode)
  (:hook-into prog-mode text-mode)
  (:option whitespace-style '(face tabs missing-newline-at-eof)
           show-trailing-whitespace t)
  ;; Disable `show-trailing-whitespace' in some modes:
  (:with-hook (special-mode-hook
               term-mode-hook
               vterm-mode-hook
               comint-mode-hook
               compilation-mode-hook
               minibuffer-setup-hook
               minibuffer-mode-hook
               calendar-mode-hook
               ;; embark-mode-hook
               eshell-mode-hook
               completion-list-mode-hook
               messages-buffer-mode-hook
               diff-mode-hook)
    (:hook (lambda() (setq-local show-trailing-whitespace nil)))))
(setup (:elpaca syntax-subword)
  (:hide-mode global-subword-mode)
  (add-hook 'elpaca-after-init-hook #'global-syntax-subword-mode))
(setup (:elpaca ace-window)
  ;; Prefixed with C-u swaps, see 'M-h f ace-window'
  (:global "M-o" ace-window))

;; new remap format is "<remap> <what-to-remap>" #'my-function
(setup (:elpaca helpful)
  ;; Helpful.el
  (:global
   [remap describe-function] helpful-callable
   [remap describe-command] helpful-command
   [remap describe-variable] helpful-variable
   [remap describe-key] helpful-key
   [remap describe-symbol] helpful-symbol))

(setup (:elpaca which-key)
  ;; :defer 10
  (setopt which-key-idle-delay 2.0))


(setup (:elpaca jump-char)
  (:load-after kmacro) ; bc I only use this for macro-ing anyway

  (:global
   "C-c j f" jump-char-forward
   "C-c j b" jump-char-backward
   "C-c j m f" jump-char-forward-set-mark
   "C-c j m b" jump-char-backward-set-mark))

(setup (:elpaca delight))
(setq custom-file (expand-file-name "custom.el" no-littering-var-directory))

(load custom-file 'noerror 'nomessage)
(setup (:elpaca async))
(setup (:elpaca detached)
  (:global
   ;; Replace `async-shell-command' with `detached-shell-command'
   [remap async-shell-command] detached-shell-command
   ;; Replace `compile' with `detached-compile'
   [remap compile] detached-compile
   [remap recompile] detached-compile-recompile
   ;; Replace built in completion of sessions with `consult'
   [remap detached-open-session] detached-consult-session)
  (:option detached-show-output-on-attach t)
  (detached-init))
(setup (:elpaca vertico)
  (defun f/minibuffer-backward-delete-word (arg)
    "Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
    (interactive "p")
    (delete-region (point) (progn (backward-word arg) (point))))

  (defun f/minibuffer-delete-word (arg)
    "Delete characters forward until the end of a word.
Like `kill-word' but doesn't add deleted words to kill ring."
    (interactive "p")
    (delete-region (point) (progn (forward-word arg) (point))))

  (defun f/minibuffer-delete-line (arg)
    "Delete characters forward until the end of the line.
Like `kill-line' but doesn't add deleted characters to kill ring."
    (interactive "p")
    (delete-region (point) (progn (end-of-line arg) (point))))
  ;; prevent cursor on minibuffer
  (:with-hook minibuffer-setup-hook
    (:hook cursor-intangible-mode))

  (:with-map vertico-map
    (:bind "?" minibuffer-completion-help
           "M-RET" minibuffer-force-complete-and-exit
           "M-TAB" minibuffer-complete
           "M-<backspace>" f/minibuffer-backward-delete-word
           "M-D" f/minibuffer-backward-delete-word ; was down-list
           "C-M-d" backward-delete-char ; was down-list
           "M-d" f/minibuffer-delete-word
           "C-k" f/minibuffer-delete-line
           "C-M-k" kill-line
           ;; "M-h" dw/minibuffer-backward-kill

           ;; can be reversed because of `vertico-reverse-mode', but no:
           ;; "C-p" vertico-next
           ;; "C-n" vertico-previous
           ))
  (:option vertico-scroll-margin 4 ;; Different scroll margin
           ;;;; Show more candidates
           ;; setq vertico-count 20
           ;;;; Grow and shrink the Vertico minibuffer
           ;; vertico-resize t
           ;;;; Optionally enable cycling for `vertico-next' and `vertico-previous'.
           vertico-cycle t)

  ;; vertico-minibuffer-settings
  ;; - Hide commands in M-x which do not work in the current mode.
  ;; # Emacs 28
  ;; - Vertico commands are hidden in normal buffers.
  (setopt read-extended-command-predicate #'command-completion-default-include-p
          enable-recursive-minibuffers t
          completion-cycle-threshold 3 ; TAB cycle if there are only few candidates
          ;; Do not allow the cursor in the minibuffer prompt
          minibuffer-prompt-properties '(read-only
                                         t
                                         cursor-intangible
                                         t face minibuffer-prompt))
  (:with-hook 'elpaca-after-init-hook
    (:hook vertico-mode)))
;; Persist history over Emacs restarts. Vertico sorts by history position.
(setup savehist
  (:option savehist-additional-variables '(kill-ring
                                           compile-command
                                           search-ring
                                           regexp-search-ring)
           history-length 1000
           history-delete-duplicates t)

  ;; History lengths can also be limited:
  ;; See [[https://www.reddit.com/r/emacs/comments/i961nn/comment/g1d87tf/?context=3][Emacs dragged down by massive 'history' file : emacs#demosthenex]]
  ;; Found my savehist was HUGE and locking up emacs every 5 min
  (put 'savehist-minibuffer-history-variables 'history-length 1000)
  (put 'org-read-date-history                 'history-length 1000)
  (put 'read-expression-history               'history-length 1000)
  (put 'org-table-formula-history             'history-length 1000)
  (put 'extended-command-history              'history-length 1000)
  (put 'ido-file-history                      'history-length 1000)
  (put 'helm-M-x-input-history                'history-length 1000)
  (put 'minibuffer-history                    'history-length 1000)
  (put 'ido-buffer-history                    'history-length 1000)
  (put 'buffer-name-history                   'history-length 1000)
  (put 'file-name-history                     'history-length 1000)
  ;; # [2022-11-09 Wed 17:15:35 -03]

  (:hook-into elpaca-after-init-hook))
(setup (:elpaca orderless)
  (:option completion-category-defaults nil
           ;; served well completion-styles '(substring orderless flex)
           completion-styles '(orderless initials substring basic)
           completion-category-overrides '((file (styles basic partial-completion)))
           ;; completion-category-overrides '((command (styles orderless+initialism))
           ;;                                 (symbol (styles orderless+initialism))
           ;;                                 (variable (styles orderless+initialism)))
           ;; Integrate with company
           orderless-component-separator "[ &]"
           ;; Case matching
           orderless-smart-case t
           ;; completion-ignore-case t
           ;; read-file-name-completion-ignore-case t
           ;; read-buffer-completion-ignore-case t
           )

  (defun just-one-face (fn &rest args)
    (let ((orderless-match-faces [completions-common-part]))
      (apply fn args)))

  (:advise company-capf--candidates :around #'just-one-face)
  )
;; Enable richer annotations using the Marginalia package
(setup (:elpaca marginalia)
  (:hook-into elpaca-after-init-hook)
  ;; Either bind `marginalia-cycle` globally or only in the minibuffer
  ;; (:bind "M-A" marginalia-cycle)
  (:with-map minibuffer-local-map
    (:bind "M-A" marginalia-cycle))
  (setopt marginalia-align 'left
          marginalia-field-width 120))
(setup (:elpaca consult)
  (:global "C-s" consult-line ;; Was search-forward
           "C-x b" consult-buffer ;; Was switch-to-buffer
           "C-r" consult-history ;; #TODO-ithink was isearch-backward
           "C-c o s" consult-org-heading
           ))
;; note: consult-outline & consult-org-heading
(setup (:elpaca embark)
       (:elpaca embark-consult)
  (:load-after consult)
  (:global "C-." embark-act
           ;; "C-;" embark-dwim
           "C-h B" embark-bindings)
  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command)

  ;; Hide the mode line of the Embark live/completions buffers
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none))))
  ;; (:hook embark-collect-mode consult-preview-at-point-mode)
  )
(setup (:elpaca corfu)
       (:elpaca corfu-terminal)

  (:with-map corfu-map
    (:bind "C-SPC" corfu-insert-separator)
    (:unbind "C-n"
             "C-p"))
  (:option corfu-cycle t
           corfu-auto t
           corfu-auto-delay 0.1
           corfu-auto-prefix 2
           ;; corfu-quit-at-boundary 'separator ; Using M-SPC will activate orderless-style matching with space-separated fields.
           ;; See [[https://www.reddit.com/r/emacs/comments/sh3lio/orderless_corfu_make_the_component_separator/][Orderless + Corfu: Make '*' the component separator? : emacs]]
           ;; lsp-completion-provider :none ; this otherwise conflicts with corfu
           corfu-preview-current nil)

  ;; (:with-hook 'elpaca-after-init-hook
  ;;   (:hook global-corfu-mode))
  (global-corfu-mode 1)


  ;; https://codeberg.org/akib/emacs-corfu-terminal#headline-6
  (unless (display-graphic-p)
    (corfu-terminal-mode 1))

  ;; enable corfu on minibuffers like eval-expression
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      ;; (setq-local corfu-auto nil) ;; Enable/disable auto completion
      (setq-local corfu-echo-delay nil ;; Disable automatic echo and popup
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer))
(setup (:elpaca prescient)
       (:elpaca corfu-prescient)
  (:load-after corfu)
  (:with-hook corfu-mode-hook
    (:hook corfu-prescient-mode))
  (:option prescient-persist-mode t))
;; Add extensions
(setup (:elpaca cape)
  ;; Bind dedicated completion commands
  ;; Alternative prefix keys: C-c p, M-p, M-+, ...
  (:global "C-c p p" completion-at-point ;; capf
           "C-c p t" complete-tag        ;; etags
           "C-c p d" cape-dabbrev        ;; or dabbrev-completion
           "C-c p h" cape-history
           "C-c p f" cape-file
           "C-c p k" cape-keyword
           "C-c p s" cape-elisp-symbol
           "C-c p e" cape-elisp-block
           "C-c p a" cape-abbrev
           "C-c p l" cape-line
           "C-c p w" cape-dict
           "C-c p :" cape-emoji
           "C-c p \\" cape-tex
           "C-c p _" cape-tex
           "C-c p ^" cape-tex
           "C-c p &" cape-sgml
           "C-c p r" cape-rfc1345)
  ;; Add to the global default value of `completion-at-point-functions' which is
  ;; used by `completion-at-point'.  The order of the functions matters, the
  ;; first function returning a result wins.  Note that the list of buffer-local
  ;; completion functions takes precedence over the global list.
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file)
  (add-to-list 'completion-at-point-functions #'cape-elisp-block)
  ;;(add-to-list 'completion-at-point-functions #'cape-history)
  ;;(add-to-list 'completion-at-point-functions #'cape-keyword)
  ;;(add-to-list 'completion-at-point-functions #'cape-tex)
  ;;(add-to-list 'completion-at-point-functions #'cape-sgml)
  ;;(add-to-list 'completion-at-point-functions #'cape-rfc1345)
  ;;(add-to-list 'completion-at-point-functions #'cape-abbrev)
  ;;(add-to-list 'completion-at-point-functions #'cape-dict)
  ;;(add-to-list 'completion-at-point-functions #'cape-elisp-symbol)
  ;;(add-to-list 'completion-at-point-functions #'cape-line)
  )
(setup (:elpaca tempel)

  ;; Require trigger prefix before template name when completing.
  ;; (:option tempel-trigger-prefix "<")
  (:global "M-+" tempel-complete ;; Alternative tempel-expand
           "M-*" tempel-insert)

  ;; Setup completion at point
  (defun tempel-setup-capf ()
    ;; Add the Tempel Capf to `completion-at-point-functions'.
    ;; `tempel-expand' only triggers on exact matches. Alternatively use
    ;; `tempel-complete' if you want to see all matches, but then you
    ;; should also configure `tempel-trigger-prefix', such that Tempel
    ;; does not trigger too often when you don't expect it. NOTE: We add
    ;; `tempel-expand' *before* the main programming mode Capf, such
    ;; that it will be tried first.
    (setq-local completion-at-point-functions
                (cons #'tempel-expand
                      completion-at-point-functions)))


  ;; Optionally make the Tempel templates available to Abbrev,
  ;; either locally or globally. `expand-abbrev' is bound to C-x '.
  ;; (add-hook 'prog-mode-hook #'tempel-abbrev-mode)
  ;; (global-tempel-abbrev-mode)
  (:with-hook prog-mode-hook text-mode-hook
              (:hook tempel-setup-capf)))
(setup eglot ; built-in since Emacs 29
  (:option eglot-send-changes-idle-time 0.2)
  (:with-feature eldoc ; eglot uses eldoc for ui documentation
    ;; (:elpaca eldoc-box)
    ;; (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode)
    (:option eldoc-idle-delay 0.1))
  )
;;; UI
(menu-bar-mode -1)    ; Disable menu bar
(tool-bar-mode -1)    ; Disable toolbar
;; (ALARM-EMACS27-conflict): scroll-bar-mode is void on emacs-nox
(scroll-bar-mode -1)  ; Disable scrolllbar

(blink-cursor-mode 1)
(setopt blink-cursor-blinks 1)

(column-number-mode 1) ; column number in mode-line
(line-number-mode 1) ; line number in mode-line
;; (global-hl-line-mode 1) ;; highlight current line
;; (visual-line-mode 1)
;; (toggle-truncate-lines -1)
;; Font configuration
;; Check if on Windows and change font (Windows-NT)
(defvar v/get-default-font
  (if (eq system-type 'windows-nt)
      ;; "Consolas"
      ;; "Literation Mono Nerd Font" on Linux or "LiterationMono Nerd Font" on (Windows-NT)
      "LiterationMono Nerd Font"
    "Literation Mono Nerd Font")
  "Sets the default font based on the system type.
To be used with `f/set-font'.")

(defvar v/get-default-font-size
  (if (eq system-type 'windows-nt)
      11
    11)
  "Sets the default font size based on the system type.
To be used with `f/set-font'.")

(defun f/set-font (&rest args)
  "Set font face using `set-face-attribute' and keywords.
Available keywords are:

`:name' = a string with the font name like \"Liberation Mono\" or
\"DejaVu Sans Mono\". It defaults to the value from the helper
function `f/get-default-font' that returns a string.

`:size' = a number that is multiplied by 10 internally to pass as
\":height\" to `set-face-attribute'. It defaults to the value
from the helper function `f/get-default-font-size' that returns a
number."
  (let* ((font (or (plist-get args :name) v/get-default-font))
         (size (or (plist-get args :size) v/get-default-font-size)))
    (set-face-attribute 'default nil
                        :font font
                        :height (* size 10))))

(if (daemonp) ;; Load font after daemon frame is created/init hook
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (with-selected-frame frame
                  (f/set-font))))
  (add-hook 'elpaca-after-init-hook
            (lambda () (f/set-font))))
;; end set font
(setopt cursor-type 'box
        ;; display-line-numbers-type 'relative
        linum-relative-current-symbol ""
        inhibit-startup-screen t
        auto-hscroll-mode 'current-line ; nano-like line horizontal scrolling ; https://emacs.stackexchange.com/questions/40864/scroll-only-current-line-when-truncating-lines
        use-dialog-box nil)
(setup display-line-numbers
  ;; disable line numbers for some modes
  (:hook-into prog-mode text-mode html-mode)
  (:with-hook (term-mode-hook
               shell-mode-hook
               eshell-mode-hook
               org-mode-hook)
    (:hook (lambda() (display-line-numbers-mode -1)))))
(setopt show-paren-mode t
        show-paren-delay 0.01
        show-paren-style 'parenthesis)

(setup (:elpaca rainbow-delimiters)
  (:hook-into emacs-lisp-mode))
(add-to-list 'custom-theme-load-path (concat user-emacs-directory "themes/"))
(defun on-after-init ()
  (unless (display-graphic-p (selected-frame))
    (set-face-background 'default "unspecified-bg" (selected-frame))))
(add-hook 'window-setup-hook #'on-after-init)
;; idk if the string "unspecified-bg" specifically has to be used but it works


;; [[https://stackoverflow.com/questions/19054228/emacs-disable-theme-background-color-in-terminal/33298750#33298750][Emacs: disable theme background color in terminal - Stack Overflow]]
(defun on-frame-open (&optional frame)
  "If the FRAME created in terminal don't load background color."
  (unless (display-graphic-p frame)
    (set-face-background 'default "unspecified-bg" frame)))
(add-hook 'after-make-frame-functions #'on-frame-open)
(setup (:elpaca auto-dark)
  (setopt auto-dark-dark-theme 'neron-dark
          auto-dark-light-theme 'neron-light)
  (auto-dark-mode t)
  (:hide-mode))
(setup ibuffer
  (:option ibuffer-show-empty-filter-groups nil
           ibuffer-saved-filter-groups (quote
                                        (("default"
                                          ("shell"      (mode . shell-mode))
                                          ("dired"      (mode . dired-mode))
                                          ("org"        (mode . org-mode))
                                          ("emacs-lisp" (mode . emacs-lisp)))))
           ibuffer-expert t)
  (:hook (lambda() (ibuffer-switch-to-saved-filter-groups "default")))
  (:global "C-x C-b" ibuffer))
(setup display-fill-column-indicator-mode
  (:hook-into prog-mode text-mode)
    (:option display-fill-column-indicator-column 79)
    (display-fill-column-indicator-mode 1))
(setup (:elpaca doom-modeline)
  (:hook-into elpaca-after-init-hook)
  (:option doom-modeline-height 15
           doom-modeline-buffer-encoding nil
           ;; display-time-format '%H:%M'
           doom-modeline-percent-position nil
           doom-modeline-icon nil
           doom-modeline-enable-word-count nil ; Performance
           ))
(set-window-margins nil 1)
(setup (:elpaca fira-code-mode)
  (:only-if (display-graphic-p))
  (:hook-into prog-mode)
  (unless (display-graphic-p) ; redundant with :only-if?
    (fira-code-mode -1))
  (with-eval-after-load 'fira-code-mode
    (dolist (ligature '("-}"))
      (add-to-list 'fira-code-mode-disabled-ligatures ligature))))
(setup (:elpaca transpose-frame)
  (defun f/rotate-frame-clockwise-or-default ()
    "Rotate frame clockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (window-parent)
        (rotate-frame-clockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  (defun f/rotate-frame-anticlockwise-or-default ()
    "Rotate frame anticlockwise if more than one frame exists; otherwise, execute default command."
    (interactive)
    (if (window-parent)
        (rotate-frame-anticlockwise)
      ;; Default command:
      (call-interactively #'move-to-window-line-top-bottom)))

  (:global "M-r" #'f/rotate-frame-clockwise-or-default ;; was #'move-to-window-line-top-bottom
           "M-S-r" #'f/rotate-frame-anticlockwise-or-default ;; was #'move-to-window-line-top-bottom
           ))
(setup (:elpaca multiple-cursors)
  (:global "C-S-c C-S-c" mc/edit-lines
           "C-<" mc/mark-previous-like-this
           "C->" mc/mark-next-like-this
           "C-c C-<" mc/mark-all-like-this))
;; source https://www.emacswiki.org/emacs/HalfScrolling
(defun window-half-height ()
  (max 1 (/ (1- (window-height (selected-window))) 2)))

(cl-defun window-div-height (&optional (n 2))
  (max 1 (/ (1- (window-height (selected-window))) n)))

(defun scroll-up-half ()
  (interactive)
  (scroll-up (window-half-height)))

(defun scroll-down-half ()
  (interactive)
  (scroll-down (window-half-height)))

;;;###autoload
(defun scroll-up-div ()
  (interactive)
  (scroll-up (window-div-height 10)))

;;;###autoload
(defun scroll-down-div ()
  (interactive)
  (scroll-down (window-div-height 10)))

(keymap-global-set "<remap> <scroll-up-command>" #'scroll-up-div)
(keymap-global-set "<remap> <scroll-down-command>" #'scroll-down-div)
(setup pixel-scroll
  ;; (:only-if (display-graphic-p))
  (pixel-scroll-precision-mode)
  (:hook-into elpaca-after-init-hook)
  (:option pixel-scroll-precision-use-momentum t
           pixel-scroll-precision-large-scroll-height 5.0
           mouse-wheel-scroll-amount '(1 ((shift) . 1)) ; one line at a time
           mouse-wheel-progressive-speed nil ; don't accelerate scrolling
           mouse-wheel-follow-mouse 't)) ; scroll window under mouse
(defun dired-find-alternate-file-up ()
  "Sames as `dired-find-alternate-file' but go up one directory instead."
  (interactive)
  (find-alternate-file ".."))
(defun mu-open-in-external-app ()
  "Open the file where point is or the marked files in Dired in external app.

The app is chosen from your OS's preference."
  (interactive)
  (let* ((file-list
          (dired-get-marked-files)))
    (mapc
     (lambda (file-path)
       (let ((process-connection-type nil))
         (start-process "" nil "launch" file-path)))
     file-list)))
;; default terminal application path
(defvar v/terminal (getenv "TERMINAL")
  "The default terminal environment vairable.")
;;; function to open new terminal window at current directory
(defun tmtxt/open-current-dir-in-terminal ()
  "Open current directory in 'dired-mode' in terminal application."
  (interactive)
  (shell-command (concat
                  (shell-quote-argument v/terminal)
                  " "
                  "--working-directory"
                  " "
                  (shell-quote-argument (file-truename default-directory)))))

;; (define-key dired-mode-map (kbd "<f4>") 'tmtxt/open-current-dir-in-terminal) ;; was kmacro-end-or-call-macro
(setup (:elpaca dired-rainbow)
  (require 'dired-rainbow)
  ;; * `dired-rainbow-define` - add face by file extension
  ;; * `dired-rainbow-define-chmod` - add face by file permissions
  (dired-rainbow-define-chmod directory       "#69aaff" "d.*")
  (dired-rainbow-define-chmod executable-unix "#61bd09" "-.*x.*")
  (dired-rainbow-define html             "#f88785" ("css" "less" "sass" "scss" "htm" "html" "jhtm" "mht" "eml" "mustache" "xhtml"))
  (dired-rainbow-define xml              "#b8aa07" ("xml" "xsd" "xsl" "xslt" "wsdl" "bib" "json" "msg" "pgn" "rss" "yaml" "yml" "rdata"))
  (dired-rainbow-define document         "#a89bff" ("docm" "doc" "docx" "odb" "odt" "pdb" "pdf" "ps" "rtf" "djvu" "epub" "odp" "ppt" "pptx"))
  (dired-rainbow-define markdown         "#bda38e" ("org" "etx" "info" "markdown" "md" "mkd" "nfo" "pod" "rst" "tex" "textfile" "txt"))
  (dired-rainbow-define database         "#69aaff" ("xlsx" "xls" "csv" "accdb" "db" "mdb" "sqlite" "nc"))
  (dired-rainbow-define media            "#fd892c" ("mp3" "mp4" "MP3" "MP4" "avi" "mpeg" "mpg" "flv" "ogg" "mov" "mid" "midi" "wav" "aiff" "flac"))
  (dired-rainbow-define image            "#f88785" ("tiff" "tif" "cdr" "gif" "ico" "jpeg" "jpg" "png" "psd" "eps" "svg" "webp"))
  (dired-rainbow-define log              "#d2a022" ("log"))
  (dired-rainbow-define shell            "#fd892c" ("awk" "bash" "bat" "sed" "sh" "zsh" "vim"))
  (dired-rainbow-define interpreted      "#61bd09" ("py" "ipynb" "rb" "pl" "t" "msql" "mysql" "pgsql" "sql" "r" "clj" "cljs" "scala" "js"))
  (dired-rainbow-define compiled         "#00bbb7" ("asm" "cl" "lisp" "el" "elc" "eln" "c" "h" "c++" "h++" "hpp" "hxx" "m" "cc" "cs" "cp" "cpp" "go" "f" "for" "ftn" "f90" "f95" "f03" "f08" "s" "rs" "hi" "hs" "pyc" ".java"))
  (dired-rainbow-define executable       "#61bd09" ("exe" "msi"))
  (dired-rainbow-define compressed       "#61bd09" ("7z" "zip" "bz2" "tgz" "txz" "gz" "xz" "z" "Z" "jar" "war" "ear" "rar" "sar" "xpi" "apk" "xz" "tar" "rsn" "vsix"))
  (dired-rainbow-define packaged         "#fd892c" ("deb" "rpm" "apk" "jad" "jar" "cab" "pak" "pk3" "vdf" "vpk" "bsp"))
  (dired-rainbow-define encrypted        "#b8aa07" ("gpg" "pgp" "asc" "bfe" "enc" "signature" "sig" "p12" "pem"))
  (dired-rainbow-define fonts            "#69aaff" ("afm" "fon" "fnt" "pfb" "pfm" "ttf" "otf"))
  (dired-rainbow-define partition        "#f88785" ("dmg" "iso" "bin" "nrg" "qcow" "toast" "vcd" "vmdk" "bak"))
  (dired-rainbow-define vc               "#69aaff" ("git" "gitignore" "gitattributes" "gitmodules"))
  ;; How it works:
  ;; After defining `dired-rainbow-define'[-chmod], it creates faces with
  ;; the provided SYMBOLs and FACE-PROPS as the default. Then the faces
  ;; can be individually customized on a theme file, overriding the
  ;; default FACE-PROPS. E.g.:
  ;; For (dired-rainbow-define markdown...), the face `dired-rainbow-markdown-face'
  ;; is created.
  )

(setup (:elpaca dired-narrow))
(setup (:elpaca dired-subtree))

(setup (:elpaca dired-efap)
  (:bind "r" dired-efap)
  (setopt dired-efap-initial-filename-selection nil))

(setup (:elpaca all-the-icons-dired)
  (:hook-into dired-mode))

(setup dired
  ;; (:elpaca dired-rainbow) ; bugged on elpaca?
  ;; (:elpaca dired-hacks-utils)
  (:elpaca diredfl)

  ;; #TODO-test dired-before-readin-hook

  ;; dired-single
  ;; joseph-single-dired
  ;; obsoleted by `dired-kill-when-opening-new-dired-buffer'

  (:require dired-x dired-aux)
  (:option dired-listing-switches "-lFAh1v --si --group-directories-first" ;; ls flags
           ls-lisp-dirs-first t ;; show directories on top of the list
           ;; delete-by-moving-to-trash t ;; move to trash instead of hard deleting
           ;; dired-omit-files-p t
           dired-recursive-copies #'always
           dired-recursive-deletes #'always
           ;; Compress/Archive files
           dired-compress-directory-default-suffix ".tar.zst"
           dired-compress-file-alist '(("\\.zst\\'" . "zstd -qf -11 --rm -o %o %i"))
           dired-compress-files-alist '(("\\.tar\\.zst\\'" . "tar -cf - %i | zstd -11 -o %o"))
           ;; prompt
           dired-deletion-confirmer #'y-or-n-p
           dired-kill-when-opening-new-dired-buffer t ; emacs 28.1 dired-single
           dired-dwim-target t ; [[https://emacs.stackexchange.com/questions/5603/how-to-quickly-copy-move-file-in-emacs-dired/5604#5604][How to quickly copy/move file in Emacs Dired? - Emacs Stack Exchange]]
           dired-hide-details-hide-symlink-targets nil ; always show where symlink points to
           )

  (:hook dired-hide-details-mode
         ;; dired-hide-dotfiles-mode
         auto-revert-mode
         diredfl-mode)

  ;; Enable disabled commands
  (:put-enable dired-find-alternate-file)

  ;; [remap dired-find-file] dired-single-buffer
  ;; [remap dired-mouse-find-file-other-window] dired-single-buffer-mouse
  ;; [remap dired-up-directory] dired-single-up-directory

  (defun f/dired-find-home ()
    (interactive)
    (dired (getenv "HOME")))
  (:bind "RET" mu-open-in-external-app
         "." dired-hide-dotfiles-mode ;; was dired-clean-directory
         "/" dired-narrow-fuzzy
         "TAB" dired-subtree-toggle
         "S-TAB" dired-subtree-cycle
         "C-c C-t" tmtxt/open-current-dir-in-terminal
         "f" dired-find-file
         "b" dired-up-directory
         ;; vim keys are better at this stuff i guess
         ;; vim keys because we live life on the edge
         "h" dired-up-directory        ;; was M-x describe-mode
         "j" dired-next-line           ;; was M-x dired-goto-file
         "k" dired-previous-line       ;; was M-x dired-do-kill-lines
         "l" dired-find-file
         "SPC" dired-mark
         "~" f/dired-find-home

         ;; ;; dired-single was not working on Emacs 28+ but `joseph-single-dired' is.
         ;; [remap dired-find-file] dired-single-buffer
         ;; [remap dired-mouse-find-file-other-window] dired-single-buffer-mouse
         ;; [remap dired-up-directory] dired-single-up-directory ;; was M-x dired-do-redisplay
         )

  ;; (eval-after-load 'dired '(progn (require 'joseph-single-dired)))
  ;; (:with-feature joseph-single-dired
  ;;   (:load-after dired))

  ;; show current directory in the header
  (defun f/dired-dir-header-line ()
    "Uses `header-line-format' to display the current directory."
    (interactive)
    (setq-local header-line-format
                '((:eval (abbreviate-file-name default-directory)))))
  ;; my/dired-dir-header-line

  (add-hook 'dired-mode-hook 'f/dired-dir-header-line)
  ) ; "(setup dired..." ends here

;; customize faces with =dired-subtree-depth-[1-6]-face=
(setup-elpaca transient) ; keyboard menu for magit.
;; fix elpaca version mismatch
;; See [[https://github.com/progfolio/elpaca/issues/324][[Bug/Support]: Error installing magit · Issue #324 · progfolio/elpaca]]
(setup-elpaca magit
  ;; For dotfiles
  (defvar v/magit-git-global-arguments--bare-git-dir-dotfiles
    (concat "--git-dir=" (expand-file-name "~/.local/dotfiles.git/"))
    "Git command argument pointing to the location of the bare git repository to track dotfiles.")

  (defvar v/magit-git-global-arguments--bare-work-tree-dotfiles
    (concat "--work-tree=" (expand-file-name "~"))
    "Git command argument location of the git repository's work directory to track files.")

  (defvar v/magit-git-global-arguments--remove-list
    (list v/magit-git-global-arguments--bare-git-dir-dotfiles
          v/magit-git-global-arguments--bare-work-tree-dotfiles)
    "List containing variables to be removed when running
`magit-status' with custom `magit-git-global-arguments'.")

  ;; use maggit on git bare repos like dotfiles repos, don't forget to
  ;; change `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' to your needs
  (defun f/magit-status-bare-dotfiles ()
    "set --git-dir and --work-tree in `magit-git-global-arguments' to `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' and calls `magit-status'"
    (interactive)
    (require 'magit-git)

    ;; Cleanup before adding again in case another function similar to
    ;; this one but with different arguments was used previously.
    (dolist (var v/magit-git-global-arguments--remove-list)
      (when var
        (setq magit-git-global-arguments (remove var magit-git-global-arguments))))
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-git-dir-dotfiles)
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-work-tree-dotfiles)
    (call-interactively 'magit-status))

  (defun f/magit-status ()
    "Removes --git-dir and --work-tree in `magit-git-global-arguments' and calls `magit-status'."
    (interactive)
    (require 'magit-git)
    (dolist (var v/magit-git-global-arguments--remove-list)
      (when var
        (setq magit-git-global-arguments (remove var magit-git-global-arguments))))
    (call-interactively 'magit-status))

  (keymap-global-unset "C-x g") ; unbind default `magit-status'
  (:global
   ;; [remap magit-status] f/magit-status
   "C-x g g" f/magit-status
   "C-x g d" f/magit-status-bare-dotfiles)

  ;; **** Git add to bare repo from dired
  (defun f/dired-bare-git-add-dotfiles (&optional arg)
    "Execute 'git add' command for current or marked files in Dired mode.
With prefix ARG, prompt for additional arguments to pass to the command."
    (interactive "P")
    (let* ((files (dired-get-marked-files nil arg))
           (git-cmd-list (append '("git")
                                 (list
                                  v/magit-git-global-arguments--bare-git-dir-dotfiles
                                  v/magit-git-global-arguments--bare-work-tree-dotfiles)))
           (git-cmd (mapconcat #'concat git-cmd-list " "))
           (output (mapconcat (lambda (file)
                                (shell-command-to-string
                                 (concat git-cmd " add --verbose " (shell-quote-argument file))))
                              files
                              "\n")))
      (message "Git add command completed:\n%s" output)))

  ;; for normal git actions
  ;; **** Git add to bare repo from dired
  (defun f/dired-git-add (&optional arg)
    "Execute 'git add' command for current or marked files in Dired mode.
With prefix ARG, prompt for additional arguments to pass to the command."
    (interactive "P")
    (let* ((files (dired-get-marked-files nil arg))
           (git-cmd "git")
           (output (mapconcat (lambda (file)
                                (shell-command-to-string
                                 (concat git-cmd " add --verbose " (shell-quote-argument file))))
                              files
                              "\n")))
      (message "Git add command completed:\n%s" output)))

  (keymap-set dired-mode-map "C-c g d a" #'f/dired-bare-git-add-dotfiles)
  (keymap-set dired-mode-map "C-c g g a" #'f/dired-git-add)

  (require '11xx-vot))

(add-hook 'emacs-startup-hook
  (lambda ()
    (message "*** Emacs loaded in %s seconds with %d garbage collections."
             (emacs-init-time "%.2f")
             gcs-done)))
