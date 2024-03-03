;; (require '11xx-package)
(require '11xx-setup)
(require '11xx-functions)

(setup emacs
  (:load-after startup)
  ;; Packages for extended/basic Emacs functionality
  (:package jump-char
            ace-window
            helpful
            which-key)

  ;; Encoding, pretty much anything other than strictly english ascii
  ;; writing requires a different encoding. So use UTF-8.
  (prefer-coding-system 'utf-8)
  (setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING))

  ;; [[http://xahlee.info/emacs/emacs/emacs_file_encoding.html][Emacs: Set Default File Encoding]]
  ;; UTF-8 as default encoding
  (set-language-environment "UTF-8")
  (set-default-coding-systems 'utf-8)
  (set-keyboard-coding-system 'utf-8-unix)

  (setq-default buffer-file-coding-system 'utf-8-unix) ; specifically for prefering LF over CRLF

  ;; do this especially on Windows, else python output problem
  (set-terminal-coding-system 'utf-8-unix)
  ;; To force UTF-8 on specific files, add a file local variable with:
  ;; M-x add-file-local-variable-prop-line RET coding RET utf-8 RET
  ;; or
  ;; M-x add-file-local-variable RET coding RET utf-8 RET
  ;; # [2022-11-08 Tue 17:10:44 -03]
  ;; See [[https://stackoverflow.com/questions/20212703/problems-saving-file-with-unicode-characters/20564324#20564324][emacs - Problems saving file with Unicode characters - Stack Overflow]]

  ;; *** Variables
  ;; **** Backup directory variable
  (defvar v/backup-directory (concat user-emacs-directory ".backups"))
  ;; #TODO-function to test if dir exists and create it # [2022-11-15 Tue 10:49:35 -03]
  (f/check-make-directory v/backup-directory)

  ;; **** Auto-save directory variable
  (defvar v/auto-save-directory (concat user-emacs-directory ".auto-save"))
  (f/check-make-directory v/auto-save-directory)

  ;; add random number to auto save file list
  ;; (defun f/auto-save-list-file-name-function ()
  ;;   (let ((basename (concat v/auto-save-directory "/auto-save-list-"))
  ;;         (random-number (number-to-string (random))))
  ;;     (concat basename (substring random-number 0 8) "~")))

  ;; (setq auto-save-list-file-name-function #'f/auto-save-list-file-name-function)


  ;; Variables
  (:option
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
   backup-directory-alist `((".*" . ,v/backup-directory))
   auto-save-file-name-transforms `(("\\(?:[^/]*/\\)*\\(.*\\)" ,(concat v/auto-save-directory "\\\\1") t)) ; got the regex from [[https://superuser.com/questions/411982/emacs-changing-the-location-of-auto-save-files/437563#437563][Emacs: Changing the location of auto-save files - Super User]]
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
   auto-save-interval 200 ; number of keystrokes between auto-saves (default: 300)
   ;; inhibit-startup-echo-area-message "lobster"
   inhibit-startup-message 't
   ;; initial-major-mode 'fundamental-mode
   ;; initial-scratch-message 'nil
   undo-limit 1000000000
   undo-strong-limit 1000000000
   undo-outer-limit 1010000000
   ring-bell-function 'ignore
   create-lockfiles nil
   auto-window-vscroll nil
   )

  ;; use of forward-same-syntax: [[https://stackoverflow.com/questions/1771102/changing-emacs-forward-word-behaviour/2565961#2565961][emacs23 - Changing Emacs Forward-Word Behaviour - Stack Overflow]]
  ;; [[https://stackoverflow.com/questions/58300666/backward-same-syntax-in-emacs/58306071#58306071]["backward-same-syntax" in Emacs - Stack Overflow]]
  (defun f/backward-same-syntax ()
    "Wrapper for `forward-same-syntax' with negative argument."
    (interactive)
    (forward-same-syntax -1))
  ;; better alternative that includes subword same-syntax:
  ;; [[https://github.com/jpkotta/syntax-subword/blob/master/syntax-subword.el][syntax-subword/syntax-subword.el at master · jpkotta/syntax-subword]]
  (:package syntax-subword)
  ;; (global-syntax-subword-mode 1)

  (:with-mode global-subword-mode ; support camelCase cursor movement.
    (:hide-mode global-subword-mode)
    (:hook-into after-init))

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
   ;; Buffer & UI movement
   "M-o" ace-window
   ;; disabled. "M-r" window-split-toggle ; was `move-to-window-line-top-bottom'
   ;; Prefixed with C-u swaps, see 'M-h f ace-window' "M-S-o" ace-swap-window
   "C-c j f" jump-char-forward
   "C-c j b" jump-char-backward
   "C-c j m f" jump-char-forward-set-mark
   "C-c j m b" jump-char-backward-set-mark
   ;; Helpful.el
   [remap describe-function] helpful-callable
   [remap describe-command] helpful-command
   [remap describe-variable] helpful-variable
   [remap describe-key] helpful-key
   [remap describe-symbol] helpful-symbol
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

   ;; assigning `syntax-subword-forward' is not necessary just enable `global-syntax-subword-mode'
   "M-f" forward-word ; syntax-subword-forward ; alt: forward-same-syntax ; was forward-word
   "M-b" backward-word ; syntax-subword-backward ; alt: f/backward-same-syntax ; was backward-word
   )

  ;;; Minor modes
  (electric-pair-mode 1)
  (electric-indent-mode 1)
  ;; (:also-load mouse)
  ;; (xterm-mouse-mode 1) ;; xterm mouse support
  (:package smartparens) ;; #manual-smartparens
  ;; (smartparens-mode)

  (delete-selection-mode 1) ; delete marked region with backspace

  ;;; Enable disabled 'advanced' commands
  (:put-enable narrow-to-region
               narrow-to-page
               narrow-to-defun
               widen
               downcase-region)

  (add-function :after after-focus-change-function
                (lambda() (save-some-buffers t)))

  (:with-mode whitespace-mode
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

  (:with-feature which-key
    (:hook-into after-init)
    (:hide-mode)
    (:option which-key-idle-delay 2))

  (:with-hook after-init-hook
    (:hook save-place-mode))

  ) ;; "(setup emacs..." ends here

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
