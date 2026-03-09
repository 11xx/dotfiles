;; -*- lexical-binding: t; -*-
(setup emacs
  ;; Keybindings
  (:global-set
   "C-c C-/"          comment-region
   "C-c C-M-/"        uncomment-region
   "<remap> <mark-word>"  f/mark-whole-word
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
   "C-S-<left>"   shrink-window-horizontally
   "C-S-<right>"  enlarge-window-horizontally
   "C-S-<down>"   shrink-window
   "C-S-<up>"     enlarge-window
   ;; Cursor
   ;; "C-M-d" backward-delete-char ; was down-list
   "C-M-d" delete-pair ; was down-list
   ;; "M-D"   backward-kill-word
   "M-D"   delete-pair
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
 delete-by-moving-to-trash t
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
               diff-mode-hook
               messages-buffer-mode-hook)
    (:hook (lambda() (setq-local show-trailing-whitespace nil)))))
(setup (:elpaca syntax-subword)
  (:hide-mode global-subword-mode)
  (add-hook 'elpaca-after-init-hook #'global-syntax-subword-mode))
(setup (:elpaca ace-window)
  ;; Prefixed with C-u swaps, see 'M-h f ace-window'
  (:global-set "M-o" ace-window)

  ;; https://github.com/abo-abo/ace-window?tab=readme-ov-file#aw-keys
  (setopt aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)
          aw-scope 'frame))

;; new remap format is "<remap> <what-to-remap>" #'my-function
(setup (:elpaca helpful)
  ;; Helpful.el
  (:global-set
   "<remap> <describe-function>" helpful-callable
   "<remap> <describe-command>" helpful-command
   "<remap> <describe-variable>" helpful-variable
   "<remap> <describe-key>" helpful-key
   "<remap> <describe-symbol>" helpful-symbol))

(setup (:elpaca which-key)
  ;; :defer 10
  (setopt which-key-idle-delay 2.0))


(setup (:elpaca jump-char)
  (:load-after kmacro) ; bc I only use this for macro-ing anyway

  (:global-set
   "C-c j f" jump-char-forward
   "C-c j b" jump-char-backward
   "C-c j m f" jump-char-forward-set-mark
   "C-c j m b" jump-char-backward-set-mark))

(setup (:elpaca delight))
(setq custom-file (expand-file-name "custom.el" no-littering-var-directory))

(load custom-file 'noerror 'nomessage)
(setup (:elpaca async))
(setup (:elpaca detached)
  (:global-set
   ;; Replace `async-shell-command' with `detached-shell-command'
   "<remap> <async-shell-command>" detached-shell-command
   ;; Replace `compile' with `detached-compile'
   "<remap> <compile>" detached-compile
   "<remap> <recompile>" detached-compile-recompile
   ;; Replace built in completion of sessions with `consult'
   "<remap> <detached-open-session>" detached-consult-session)
  (:option detached-show-output-on-attach t)
  (detached-init))
(setup tramp
  (:require tramp)
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))
(setup desktop
  (:require)

  (defvar v/daemon-name
    (let ((d (daemonp)))
      (cond
       ((stringp d) d)
       ((eq d t)   "default")
       (t           nil)))
    "Server name this Emacs instance is running as, or nil if not a daemon.
Mirrors `daemonp': a string for named daemons (--daemon=NAME), \"default\"
for unnamed (--daemon), nil for interactive sessions.")

  (when v/daemon-name
    (setopt desktop-base-file-name (format ".emacs-%s.desktop" v/daemon-name)
            desktop-base-lock-name (format ".emacs-%s.desktop.lock" v/daemon-name)))

  (setopt desktop-dirname (expand-file-name "desktop/" no-littering-var-directory)
          desktop-auto-save-timeout 1
          desktop-save 'ask-if-new)
  (desktop-save-mode))
(setup (:elpaca eros)
  (:load-after org-mode)
  (:hook-into org-mode)
  (setopt ;; eros-eval-result-prefix    "∷ "
           eros-eval-result-duration  'command
           eros-overlays-use-font-lock t))

(provide '11xx-defaults)
