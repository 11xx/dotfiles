;; (require '11xx-package)
(require '11xx-setup)
(require '11xx-functions)

(setup emacs
  (require 'utf8-default)
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
   "C-c i t" f/current-timestamp
   ;; "C-c i c" f/current-timestamp-hashtag-comment
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
   ))

(use-package emacs
  :bind (("M-." . forward-list)
         ("M-," . backward-list)
         ("C-M-." . down-list) ; up-list
         ("C-M-," . backward-up-list))
  :init
  (setopt
   read-process-output-max (* 3 (* 1024 1024)) ;; 3M
   indent-tabs-mode nil ; disable tabs
   tab-width 2
   tab-stop-list (number-sequence 2 4 2) ; if `tab-width' in not read, use this
   tab-always-indent t ; when using the TAB key
   org-edit-src-content-indentation 0
   org-src-preserve-indentation nil  ; default is nil
   ;; Emacs 28: Hide commands in M-x which do not work in the
   ;; current mode.
   ;; Vertico commands are hidden in normal buffers.
   read-extended-command-predicate #'command-completion-default-include-p
   ;; Enable recursive minibuffers
   enable-recursive-minibuffers t
   ;; TAB cycle if there are only few candidates
   completion-cycle-threshold 3
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
  :config
  (add-function :after after-focus-change-function
                (lambda() (save-some-buffers t)))

  ;; Enable disabled 'advanced' commands
  (put 'narrow-to-region 'disabled nil)
  (put 'narrow-to-page   'disabled nil)
  (put 'narrow-to-defun  'disabled nil)
  (put 'widen            'disabled nil)
  (put 'downcase-region  'disabled nil)

  ;;; Minor modes
  ;; (:also-load mouse)
  ;; (xterm-mouse-mode 1) ;; xterm mouse support
  (save-place-mode 1)
  (delete-selection-mode 1) ; delete marked region with backspace
  (electric-pair-mode 1)
  (electric-indent-mode 1))

(use-package smartparens
  :disabled)
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
(use-package syntax-subword
  :disabled
  :ensure t)
;; (:with-mode global-subword-mode
;;   (:hide-mode global-subword-mode)
;;   (:hook-into after-init))
;; ;; assigning `syntax-subword-forward' is not necessary just enable `global-syntax-subword-mode'
;; "M-f" forward-word ; syntax-subword-forward ; alt: forward-same-syntax ; was forward-word
;; "M-b" backward-word ; syntax-subword-backward ; alt: f/backward-same-syntax ; was backward-word
(use-package ace-window
  :ensure t
  ;; disabled. "M-r" window-split-toggle ; was `move-to-window-line-top-bottom'
  ;; Prefixed with C-u swaps, see 'M-h f ace-window' "M-S-o" ace-swap-window
  :bind (("M-o" . ace-window)))
;; Buffer & UI movement

;; new remap format is "<remap> <what-to-remap>" #'my-function
(use-package helpful
  :ensure t
  ;; Helpful.el
  :bind
  (([remap describe-function] . helpful-callable)
   ([remap describe-command] . helpful-command)
   ([remap describe-variable] . helpful-variable)
   ([remap describe-key] . helpful-key)
   ([remap describe-symbol] . helpful-symbol)))

(use-package which-key
  :ensure t
  :defer 10
  ;; (:hide-mode)
  ;; :hook (after-init-hook)
  :config
  (setopt which-key-idle-delay 2.0))


(use-package jump-char
  :after kmacro ; bc I only use this for macro-ing anyway
  :ensure t
  :bind
  (("C-c j f" . jump-char-forward)
   ("C-c j b" . jump-char-backward)
   ("C-c j m f" . jump-char-forward-set-mark)
   ("C-c j m b" . jump-char-backward-set-mark)))

(use-package delight
  :ensure t)
(setq custom-file (expand-file-name "custom.el" no-littering-var-directory))

;;; Disabling this, uncomment if necessary

;; (defun f/check-file-touch (file)
;;   "Check if FILE exists and create it if it doesn't.

;; It uses `make-empty-file' PARENTS argument 't'."
;;   (if (not (file-exists-p file))
;;       (make-empty-file file)))

;; (f/check-file-touch custom-file)
(load custom-file 'noerror 'nomessage)
(setup (:package async))
(setup (:package detached)
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

(provide '11xx-defaults)
