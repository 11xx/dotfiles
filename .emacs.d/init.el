;; -*- lexical-binding: t; -*-

(setup (:package gcmh)
  (setq gcmh-idle-delay 30)
  (gcmh-mode 1)
  (:hide-mode))

(defun org-babel-repeat-previous-src-block ()
  "Copy previous src block excluding the content."
  (interactive)
  (let (result)
    (save-excursion
      (org-babel-previous-src-block)
      (let ((element (org-element-at-point)))
        (when (eq (car element) 'src-block)
          (let* ((pl (cadr element))
                 (lang (plist-get pl :language))
                 (switches (plist-get pl :switches))
                 (parms (plist-get pl :parameters)))
            (setq result
                  (format
                   (concat "\n#+begin_src %s\n"
                           "\n"
                           "#+end_src\n")
                   (mapconcat #'identity
                              (delq nil (list lang switches parms))
                              " ")))))))
    (and result (insert result))
    (forward-line -2))
  (recenter-top-bottom))

(defun tdir (path)
  "Expand PATH given to \"tangle-dir\" property.

If the \"tangle-dir\" property exists and is a directory, return the expanded directory path concatenated with the provided PATH.
If the property exists and is an expression, evaluate it and return the expanded result.
If the property is not found, use the base directory of the current buffer concatenated with the provided PATH."
  (let ((dir (org-entry-get nil "tangle-dir" t)))
    (if dir
        (if (string-match-p "^(" dir)
            (concat (eval (read dir)) path)
          (concat (expand-file-name dir) path))
      (concat (f-dirname (buffer-file-name)) path))))

;; (straight-use-package 'org)
(setup (:package org)
  (:load-after startup)
  (:package org-auto-tangle)

  ;; #+BEGIN_/#+END_ templates.
  (:option
   org-structure-template-alist
   '(;; Default
     ("a" . "export ascii")
     ("c" . "center")
     ("C" . "comment")
     ("e" . "example")
     ("E" . "export")
     ("h" . "export html")
     ("l" . "export latex")
     ("q" . "quote")
     ("s" . "src")
     ("v" . "verse")
     ;;; Custom
     ("sh" . "src shell")
     ("el" . "src emacs-lisp")
     ("py" . "src python")
     ("js" . "src javascript")
     ("css" . "src css")
     ("cc" . "src conf")
     ("hs" . "src haskell"))

   ;;; Org mode version 9.5:
   ;; ~org-adapt-indentation~ now defaults to ~nil~
   org-adapt-indentation nil ;; testing nil [2022-03-31 Thu 07:34:31]

   ;;; Use HTML5 on export
   org-html-html5-fancy t
   ;;; UI
   org-ellipsis " ▾"
   org-hide-emphasis-markers t
   ;;; Babel
   org-babel-shell-names '("bash" "sh" "zsh")
   ;;; Publish
   org-publish-project-alist
   '(
     ("front-end-completo-2-markdown"
      :base-directory "~/org/learning/web/front-end/2.0/org/"
      :base-extension "org"
      :publishing-directory "~/org/learning/web/front-end/2.0/publish/"
      :recursive t
      :publishing-function org-html-publish-to-html
      :headline-levels 4             ; Just the default for this project.
      :auto-preamble t)
     ("front-end-completo-2-static"
      :base-directory "~/org/learning/web/front-end/2.0/org/"
      :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|swf"
      :publishing-directory "~/org/learning/web/front-end/2.0/publish/"
      :recursive t
      :publishing-function org-publish-attachment)
     ("org" :components ("front-end-completo-2-markdown" "front-end-completo-2-static"))

     )
   org-publish-timestamp-directory (concat user-emacs-directory ".org-timestamps")
   ;;; Exporting
   ;; export async default:
   ;; Use 'M-x org-export-stack' to display current processes:
   org-export-in-background nil
   org-html-validation-link nil ; remove validade xml
   ;;; Properties
   ;; org-use-property-inheritance t ; Apparently slows down searches when on.
   ;;; Default header-args for evaluation
   org-babel-default-header-args:emacs-lisp '((:lexical . yes))
   org-image-actual-width nil
   ;; Edit src blocks in the current window instead of split
   org-src-window-setup 'current-window
   )


  (:bind "C-c C-;" org-babel-repeat-previous-src-block
         ;; "C-c C-'" org-babel-repeat-previous-src-block-reverse ;; use `org-babel-demarcate-block' instead #DONE-TO-SEND-CEMETARY 

         "C-M-p" org-previous-visible-heading ; was `backward-list'
         "C-M-n" org-next-visible-heading ; was `forward-list'
         "C-c o t l" org-toggle-link-display

         ;; Meta indentation ; `S' for Shift not working for some reason
         "M-F" org-metaright
         "M-B" org-metaleft
         "M-P" org-metaup
         "M-N" org-metadown
         ;; Cursor
         ;; "C-M-d" ; was down-list
         "M-h"   backward-delete-char ; was `org-mark-element'
         "M-H"   backward-kill-word ; was `org-mark-element' in org map
         )

  ;; [[https://orgmode.org/manual/Activation.html][src]]
  ;; Enable Org-mode commands to be available anywhere.
  (:global "C-c o l" org-store-link
           "C-c o a" org-agenda
           "C-c o c" org-capture)

  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((haskell . t)
             ;; (async   . t) ; from ob-async
             (shell   . t)
             (C       . t))))

  ;; Disable angle bracket syntax highlighting/matching
  (:hook (lambda()
           (modify-syntax-entry ?< "." org-mode-syntax-table)
           (modify-syntax-entry ?> "." org-mode-syntax-table)))

  ;; [[https://www.youtube.com/watch?v=D3FzMPZm7vY][Write Everything In Emacs Org Mode? You NEED This Plugin! - YouTube]]
  ;; org-auto-tangle: Org babel tangle file on save
  ;; [[https://github.com/yilkalargaw/org-auto-tangle][yilkalargaw/org-auto-tangle: a simple emacs package to allow org file tangling upon save]]
  (:require org-auto-tangle)
  (:hook org-auto-tangle-mode)

  ;; (:with-mode org-num-mode
  ;;   (:load-after org)
  ;;   (:hook-into org-mode))

  (:package ox-gfm)
  ;; usage in local file variables: `eval: (add-hook 'before-save-hook #'org-gfm-export-to-markdown nil t)'
  (:with-feature ox-gfm
    (:load-after org))

  (:package org-bulletproof)
  (:with-feature org-bulletproof
    (:hook-into org-mode))
  ) ;; "(setup org..." ends here

(defun f/org-export-dispatch-disable-whitespace-mode (&rest args)
  "Disable `whitespace-mode' for the Org Export Dispatch Buffer."
  (let ((buf (get-buffer "*Org Export Dispatcher*")))
    (when buf
      (with-current-buffer buf
        (setq-local show-trailing-whitespace nil)))))

(advice-add 'org-export--dispatch-action
            :before #'f/org-export-dispatch-disable-whitespace-mode)

(setup (:package org-appear)
  (:load-after org)
  ;; Toggle for links display set in (setup org)
  (:option org-appear-autolinks 'just-brackets) ; nil is default
  (:hook-into org-mode-hook))

(setup (:package visual-fill-column)
  (:load-after org)
  (:option visual-fill-column-width 120 ; use with `display-fill-column-indicator-mode'
           visual-fill-column-center-text t)
  (:hook-into org-mode))

(setup (:package (org-src-emph :type git :host github
                               :repo "TobiasZawada/org-src-emph"))
  ;; (:option ;; make this ':emph' header argument default in shell code blocks.
  ;;  org-babel-default-header-args:shell '((:emph . "'(\"<<\" \">>\")"))
  ;;  ;; See https://github.com/TobiasZawada/org-src-emph/#shell-avoid-highlighting-of-noweb-references-as-infile-documents=
  ;;  )

  (:with-hook org-mode-hook
    (:hook (lambda() (require 'org-src-emph)))))

;; override the default
(defun org-babel-noweb-wrap (&optional regexp)
  "Return regexp matching a Noweb reference.

Match any reference, or only those matching REGEXP, if non-nil.

When matching, reference is stored in match group 1."
  (rx-to-string
   `(and (or "<<" "«")
         (group
          (not (or " " "\t" "\n"))
          (? (*? any) (not (or " " "\t" "\n"))))
         (or ">>" "»"))))

(defun f/org-babel-noweb-wrap-insert-chars ()
  "Insert \"«\" and \"»\" "
  (interactive)
  (insert "«»")
  (backward-char))

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

(defun f/mark-whole-word (&optional arg allow-extend)
  "Like `mark-word', but select whole words and skips over whitespace.
If you use a negative prefix ARG then select words backward.
Otherwise select them forward.

If cursor starts in the middle of word then select that whole word.

If there is whitespace between the initial cursor position and the
first word (in the selection direction), it is skipped (not selected).

If the command is repeated or the mark is active, select the next NUM
words, where NUM is the numeric prefix argument ARG.  (Negative NUM
selects backward.)

If second argument ALLOW-EXTEND is nil don't expand selection across words.
See `mark-word' for more."
  (interactive "P\np")
  (let ((num  (prefix-numeric-value arg)))
    (unless (eq last-command this-command)
      (if (natnump num)
          (skip-syntax-forward "\\s-")
        (skip-syntax-backward "\\s-")))
    (unless (or (eq last-command this-command)
                (if (natnump num)
                    (looking-at "\\b")
                  (looking-back "\\b")))
      (if (natnump num)
          (left-word)
        (right-word)))
    (mark-word arg allow-extend)))

(defun f/infer-indentation-style ()
  "Compare number of spaces and tabs and define `indent-tabs-mode' to t or nil.

If the current buffer or file has more tabs than spaces,
set `indent-tabs-mode' to t; if it has more spaces than tabs, set it to nil;
and if inconclusive, use current `indent-tabs-mode'."
  (interactive)
  (let ((space-count (how-many "^  " (point-min) (point-max)))
        (tab-count (how-many "^\t" (point-min) (point-max))))
    (if (> space-count tab-count) (setq indent-tabs-mode nil))
    (if (> tab-count space-count) (setq indent-tabs-mode t))))
(add-hook 'prog-mode-hook #'f/infer-indentation-style)

(defun f-posix/current-timestamp ()
  "Query shell for the current time in the YYYY-mm-dd ShortWeekDay HH-MM-SS format."
  (insert (concat "# ["
                  (shell-command-to-string "printf '%s' \"$(date +'%Y-%m-%d %a %T %Z')\"")
                  "]")))

;; (Windows-NT)
(defun f-windows-nt/current-timestamp ()
  "Print ISO formatted date as '#' comment."
  (let ((timestamp (s-trim (shell-command-to-string "cmd /c echo.|powershell -Command Get-Date -Format 'yyyy-MM-dd ddd HH:mm:ss K'")))
        (hostname (s-trim (shell-command-to-string "hostname"))))
    (insert (format "# [%s] @%s" timestamp hostname))))

(defun f/current-timestamp ()
  "Check `system-type' and use either `f-posix/current-timestamp' or `f-windows-nt/current-timestamp'."
  (interactive)
  (if (not (eq system-type 'windows-nt))
      (f-posix/current-timestamp)
    (f-windows-nt/current-timestamp)))
;; # [2023-12-10 Sun 01:33:12 -03:00] @winr58

(defun f/kill-matching-lines (regexp &optional rstart rend interactive)
  "Kill lines containing matches for REGEXP.

Second and third arg RSTART and REND specify the region to operate on.
When calling this function from Lisp, you can pretend that it was
called interactively by passing a non-nil INTERACTIVE argument.
See `flush-lines' or `keep-lines' for behavior of this command.

If the buffer is read-only, Emacs will beep and refrain from deleting
the line, but put the line in the kill ring anyway.  This means that
you can use this command to copy text from a read-only buffer.
\(If the variable `kill-read-only-ok' is non-nil, then this won't
even beep.)"
  (interactive
   (keep-lines-read-args "Kill lines containing match for regexp"))
  (let ((buffer-file-name nil)) ;; HACK for `clone-buffer'
    (with-current-buffer (clone-buffer nil nil)
      (let ((inhibit-read-only t))
        (keep-lines regexp rstart rend interactive)
        (kill-region (or rstart (line-beginning-position))
                     (or rend (point-max))))
      (kill-buffer)))
  (unless (and buffer-read-only kill-read-only-ok)
    ;; Delete lines or make the "Buffer is read-only" error.
    (flush-lines regexp rstart rend interactive)))

(defun f/check-make-directory (dir)
  "Check if DIR exists and create it if it doesn't.

It uses `make-directory' PARENTS argument 't'."
  (if (not (file-exists-p dir))
      (make-directory dir t)))

(defun xdg-bin-home ()
  "Return the base directory for user specific executable files."
  (xdg--dir-home "XDG_BIN_HOME" "~/.local/bin"))

(defun xdg-state-home ()
  "Return the base directory for user specific log files."
  (xdg--dir-home "XDG_STATE_HOME" "~/.local/state"))

(defun f/read-file-contents (file-path)
  "Read the contents of the file at FILE-PATH and return it as a string."
  (with-temp-buffer
    (insert-file-contents file-path)
    (buffer-string)))

;;; Stefan Monnier <foo at acm.org>. It is the opposite of fill-paragraph
(defun unfill-paragraph (&optional region)
  "Takes a multi-line paragraph and makes it into a single line of text."
  (interactive (progn (barf-if-buffer-read-only) '(t)))
  (let ((fill-column (point-max))
        ;; This would override `fill-column' if it's an integer.
        (emacs-lisp-docstring-fill-column t))
    (fill-paragraph nil region)))

;; Handy key definition
(define-key global-map "\M-Q" 'unfill-paragraph)

(setq-default debug-on-error t) ;; Send errors to *Backtrace*
(setq comp-deferred-compilation t) ;; native compile everything
;; Silence compiler warnings
(setq native-comp-async-report-warnings-errors 'silent)

;; Set the right directory to store the native comp cache
;; NOTE: Comment this if not using native compilation [2022-04-05 Tue 20:39:06]
;; (ALARM-EMACS27-conflict)
(add-to-list 'native-comp-eln-load-path
             (expand-file-name "eln-cache/" user-emacs-directory))

(setup emacs
  (:load-after startup)
  ;; Packages for extended/basic Emacs functionality
  (:package jump-char
            ace-window
            rainbow-delimiters
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
   cursor-type 'box
   ;; display-line-numbers-type 'relative
   linum-relative-current-symbol ""
   inhibit-startup-screen t
   show-paren-mode t
   show-paren-delay 0.01
   show-paren-style 'parenthesis
   auto-hscroll-mode 'current-line ; nano-like line horizontal scrolling ; https://emacs.stackexchange.com/questions/40864/scroll-only-current-line-when-truncating-lines
   use-dialog-box nil
   ;; inhibit-startup-echo-area-message "lobster"
   inhibit-startup-message 't
   ;; initial-major-mode 'fundamental-mode
   ;; initial-scratch-message 'nil
   undo-limit 1000000000
   undo-strong-limit 1000000000
   undo-outer-limit 1010000000
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
   "M-h"          backward-delete-char ; was `mark-paragraph' global
   "M-H"          backward-kill-word ; was `mark-paragraph' global, separate override may be necessary for local maps

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
  ;;; UI
  (menu-bar-mode -1)    ; Disable menu bar
  (tool-bar-mode -1)    ; Disable toolbar
  ;; (ALARM-EMACS27-conflict): scroll-bar-mode is void on emacs-nox
  (scroll-bar-mode -1)  ; Disable scrolllbar

  (blink-cursor-mode 1)
  (setq blink-cursor-blinks 1)

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
      "Liberation Mono")
    "Sets the default font based on the system type.
To be used with `f/set-font'.")

  (defvar v/get-default-font-size
    (if (eq system-type 'windows-nt)
        11
      10)
    "Sets the default font size based on the system type.
To be used with `f/set-font'.")

  (defun f/set-font (&rest args)
    "Set font face using `set-face-attribute' and keywords.
Available keywords are:

`:font' = a string with the font name like \"Liberation Mono\" or
\"DejaVu Sans Mono\". It defaults to the value from the helper
function `f/get-default-font' that returns a string.

`:size' = a number that is multiplied by 10 internally to pass as
\":height\" to `set-face-attribute'. It defaults to the value
from the helper function `f/get-default-font-size' that returns a
number."
    (let* ((font (or (plist-get args :font) v/get-default-font))
           (size (or (plist-get args :size) v/get-default-font-size)))
      (set-face-attribute 'default nil
                          :font font
                          :height (* size 10))))

  (if (daemonp) ;; Load font after daemon frame is created/init hook
      (add-hook 'after-make-frame-functions
                (lambda (frame)
                  (with-selected-frame frame
                    (f/set-font))))
    (add-hook 'after-init-hook
              (lambda () (f/set-font))))

  ;; disable line numbers for some modes
  (:with-mode display-line-numbers-mode
    (:hook-into prog-mode text-mode html-mode)
    (:with-hook (org-mode-hook
                 term-mode-hook
                 shell-mode-hook
                 eshell-mode-hook)
      (:hook (lambda() (display-line-numbers-mode -1)))))


  ;; Note for self: maybe this is how setup.el is meant to be used? We'll see 20211212_2017
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

  (:with-mode rainbow-delimiters-mode
    (:hook-into emacs-lisp-mode))

  (:with-feature which-key
    (:hook-into after-init)
    (:hide-mode)
    (:option which-key-idle-delay 2))

  (:with-hook after-init-hook
    (:hook save-place-mode))

  ) ;; "(setup emacs..." ends here

(setup pixel-scroll
  ;; (:only-if (display-graphic-p))
  (pixel-scroll-precision-mode)
  (:hook-into after-init)
  (:option pixel-scroll-precision-use-momentum t
           pixel-scroll-precision-large-scroll-height 5.0))

;; (:option scroll-step            1 ;; emacs native var
;;          scroll-conservatively  10000 ;; emacs native var
;;          good-scroll-duration 0.1))

;; (setq scroll-step 1
;;       scroll-conservatively 10000)
;; (pixel-scroll-precision-scroll-down 1)
;; (setq scroll-step 1)

;; (global-set-key (kbd "C-c <up>") 'pixel-scroll-precision)
;; pixel-scroll-precision-mode-map <header-line> <wheel-down>

;; scroll one line at a time (less "jumpy" than defaults)

(setq mouse-wheel-scroll-amount '(1 ((shift) . 1))) ;; one line at a time
(setq mouse-wheel-progressive-speed nil) ;; don't accelerate scrolling
(setq mouse-wheel-follow-mouse 't) ;; scroll window under mouse
(setq scroll-step 1) ;; keyboard scroll one line at a time

(setup emacs
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

  (defun scroll-up-div ()
    (interactive)
    (scroll-up (window-div-height 10)))

  (defun scroll-down-div ()
    (interactive)
    (scroll-down (window-div-height 10)))

  (:global ;; [next] good-scroll-up-full-screen
           ;; [prior] good-scroll-down-full-screen
           ;; Scroll
           ;; [remap scroll-up-command] scroll-up-half
           [remap scroll-up-command] scroll-up-div
           ;; [remap scroll-down-command] scroll-down-half
           [remap scroll-down-command] scroll-down-div
           ;; [remap scroll-up-command] pixel-scroll-up
           ;; [remap scroll-down-command] pixel-scroll-down
           ))

(functionp 'json-serialize)

(setq auto-window-vscroll nil)
(setq doom-modeline-enable-word-count nil)

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(defun f/check-file-touch (file)
  "Check if FILE exists and create it if it doesn't.

It uses `make-empty-file' PARENTS argument 't'."
  (if (not (file-exists-p file))
      (make-empty-file file)))

(f/check-file-touch custom-file)
(load custom-file 'noerror 'nomessage)

(setup (:package transpose-frame)
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

(defun reload-dotemacs ()
  "Reload the Emacs init.el file."
  (interactive)
  (load-file (expand-file-name "init.el" user-emacs-directory)))

(global-set-key (kbd "C-x <f12>") #'reload-dotemacs)

(setup (:package multiple-cursors)
  (:global "C-S-c C-S-c" mc/edit-lines
           "C-<" mc/mark-previous-like-this
           "C->" mc/mark-next-like-this
           "C-c C-<" mc/mark-all-like-this))

(defun f/minibuffer-backward-delete-word (arg)
  "Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
  (interactive "p")
  (delete-region (point) (progn (backward-word arg) (point))))

(defun f/minibuffer-delete-word (arg)
  "TODO Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
  (interactive "p")
  (delete-region (point) (progn (forward-word arg) (point))))
;; also https://systemcrafters.cc/live-streams/may-21-2021/"

(defun f/minibuffer-delete-line (arg)
  "TODO Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
  (interactive "p")
  (delete-region (point) (progn (end-of-line arg) (point))))

;; (setup (:package (vertico :type git
;;                           :host github
;;                           :repo "emacs-straight/vertico"
;;                           :files ("*" "extensions/*" (:exclude ".git")))
;;                  )
(setup (:package vertico)

  ;; prevent cursor on minibuffer
  (:with-hook minibuffer-setup-hook
    (:hook cursor-intangible-mode))

  (:with-map vertico-map
    (:bind "?" minibuffer-completion-help
           "M-RET" minibuffer-force-complete-and-exit
           "M-TAB" minibuffer-complete
           "M-<backspace>" f/minibuffer-backward-delete-word
           "M-d" f/minibuffer-delete-word
           "C-M-<backspace>" backward-kill-word
           ;; "C-M-d" kill-word
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
           vertico-cycle t

           ;; Do not allow the cursor in the minibuffer prompt
           minibuffer-prompt-properties '(read-only
                                          t
                                          cursor-intangible
                                          t face minibuffer-prompt)
           )
  (:with-hook after-init-hook
    (:hook vertico-mode))
  ;; vertico-reverse-mode
  ;; (:hook-into after-init)
  )

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

  (:hook-into after-init))

(setup (:package orderless)
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
(setup (:package marginalia)
  (:hook-into after-init)
  ;; Either bind `marginalia-cycle` globally or only in the minibuffer
  ;; (:bind "M-A" marginalia-cycle)
  (:with-map minibuffer-local-map
    (:bind "M-A" marginalia-cycle)))

(setup (:package consult)
  (:global "C-s" consult-line ;; Was search-forward
           "C-x b" consult-buffer ;; Was switch-to-buffer
           "C-r" consult-history ;; #TODO-ithink was isearch-backward
           "C-c o s" consult-org-heading
           )

  (:option register-preview-delay 0
           register-preview-function #'consult-register-format
           ;; org-fold-core-style 'overlays ; fix consult-line not expanding org
                                        ; headings to show the results # [2022-08-11 Thu 06:08:58 -03]
           ;; org-fold-core-style 'text-properties
           ))
;; note: consult-outline & consult-org-heading

(setup (:package embark embark-consult)
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
  (:hook embark-collect-mode consult-preview-at-point-mode))

;; (corfu :type git :host github :repo "emacs-straight/corfu" :files ("*" (:exclude ".git")))
(setup (:package (corfu :type git
                        :host github
                        :repo "emacs-straight/corfu"
                        :files ("*" "extensions/*"
                                (:exclude ".git")))
                 corfu-terminal)

  (:with-map corfu-map
    (:bind "S-SPC" corfu-insert-separator ; was `self-insert-command'
           )
    (:unbind "C-n"
             "C-p"
             ))
  (:option corfu-cycle t
           corfu-auto t
           corfu-auto-delay 0.8
           corfu-auto-prefix 1
           ;; corfu-quit-at-boundary 'separator ; Using M-SPC will activate orderless-style matching with space-separated fields.
           ;; See [[https://www.reddit.com/r/emacs/comments/sh3lio/orderless_corfu_make_the_component_separator/][Orderless + Corfu: Make '*' the component separator? : emacs]]
           lsp-completion-provider :none ; this otherwise conflicts with corfu
           corfu-preview-current nil
           )

  (:with-hook after-init-hook
    (:hook global-corfu-mode))


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
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer)

  ;; move to minibuffer - #TODO void-variable corfu-map on startup
  ;; (defun corfu-move-to-minibuffer ()
  ;;   (interactive)
  ;;   (when completion-in-region--data
  ;;     (let ((completion-extra-properties corfu--extra)
  ;;           completion-cycle-threshold completion-cycling)
  ;;       (apply #'consult-completion-in-region completion-in-region--data))))
  ;; (keymap-set corfu-map "M-m" #'corfu-move-to-minibuffer)
  ;; (add-to-list 'corfu-continue-commands #'corfu-move-to-minibuffer)

  (defun my/lsp-mode-setup-completion ()
    (setf (alist-get 'styles (alist-get 'lsp-capf completion-category-defaults))
          '(orderless))) ;; Configure orderless
  (:with-mode lsp-completion-mode
    (:hook my/lsp-mode-setup-completion))
  )

(setup (:package prescient corfu-prescient)
  (:load-after corfu)
  (:with-hook corfu-mode-hook
    (:hook corfu-prescient-mode))
  (:option prescient-persist-mode t))

(use-package cape
  ;; Bind dedicated completion commands
  ;; Alternative prefix keys: C-c p, M-p, M-+, ...
  :bind (("C-c p p" . completion-at-point) ;; capf
         ("C-c p t" . complete-tag)        ;; etags
         ("C-c p d" . cape-dabbrev)        ;; or dabbrev-completion
         ("C-c p h" . cape-history)
         ("C-c p f" . cape-file)
         ("C-c p k" . cape-keyword)
         ("C-c p s" . cape-symbol)
         ("C-c p a" . cape-abbrev)
         ("C-c p i" . cape-ispell)
         ("C-c p l" . cape-line)
         ("C-c p w" . cape-dict)
         ("C-c p \\" . cape-tex)
         ("C-c p _" . cape-tex)
         ("C-c p ^" . cape-tex)
         ("C-c p &" . cape-sgml)
         ("C-c p r" . cape-rfc1345))

  :init
  ;; Add `completion-at-point-functions', used by `completion-at-point'.
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
  ;;(add-to-list 'completion-at-point-functions #'cape-symbol)
  ;;(add-to-list 'completion-at-point-functions #'cape-line)
  )

;; Super CAPF for emacs-lisp modes: See [[https://github.com/minad/corfu/wiki#using-cape-to-tweak-and-combine-capfs][Home · minad/corfu Wiki]]
(defun my/ignore-elisp-keywords (cand)
   (or (not (keywordp cand))
  (eq (char-after (car completion-in-region--data)) ?:)))

 (defun my/setup-elisp ()
   (setq-local completion-at-point-functions
    `(,(cape-super-capf
        (cape-capf-predicate
         #'elisp-completion-at-point
         #'my/ignore-elisp-keywords)
        #'cape-dabbrev)
      cape-file)
    cape-dabbrev-min-length 5))
(add-hook 'emacs-lisp-mode-hook #'my/setup-elisp)

(setup (:package yasnippet)
  ;; (:disabled)
  (:hide-mode yas-minor-mode)

  ;; Haskell
  (:package haskell-snippets)
  ;; Provided snippets are:
  ;;       new  - newtype
  ;;       mod  - module [simple, exports]
  ;;       main - main module and function
  ;;       let  - let bindings
  ;;       lang - language extension pragmas
  ;;       opt  - GHC options pragmas
  ;;       \    - lambda function
  ;;       inst - instance declairation
  ;;       imp  - import modules [simple, qualified]
  ;;       if   - if conditional [inline, block]
  ;;       <-   - monadic get
  ;;       fn   - top level function [simple, guarded, clauses]
  ;;       data - data type definition [inline, record]
  ;;       =>   - type constraint
  ;;       {-   - block comment
  ;;       case - case statement

  ;; (:global "C-M-i" )
  (yas-global-mode)
  )

(setup (:package tempel)

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

(setq lsp-use-plists t)
(setup (:package lsp-mode lsp-ui)
  ;; LSP Language server starter packages
  (:package lsp-haskell lsp-sh)

  (:option lsp-idle-delay 0 ; 0.5 ; 0.1
           lsp-keymap-prefix "C-c l"
           lsp-log-io nil)

  (setq lsp-ui-doc-enable nil) ; set to nil for better performance
  ) ; "(setup lsp-mode..." ends here

(setup eglot ; built-in since Emacs 29
  (:option eglot-send-changes-idle-time 0.2)
  (:with-feature eldoc ; eglot uses eldoc for ui documentation
    ;; (:package eldoc-box)
    ;; (add-hook 'eglot-managed-mode-hook #'eldoc-box-hover-mode)
    (:option eldoc-idle-delay 0.1))
  )

(setup (:package flycheck))

(add-to-list 'custom-theme-load-path (concat user-emacs-directory "themes/"))

(defun on-after-init ()
  (unless (display-graphic-p (selected-frame))
    (set-face-background 'default "unspecified-bg" (selected-frame))))
;; NOTE: The string "unspecified-bg" maked it work.
(add-hook 'window-setup-hook #'on-after-init)


;; [[https://stackoverflow.com/questions/19054228/emacs-disable-theme-background-color-in-terminal/33298750#33298750][Emacs: disable theme background color in terminal - Stack Overflow]]
(defun on-frame-open (&optional frame)
  "If the FRAME created in terminal don't load background color."
  (unless (display-graphic-p frame)
    (set-face-background 'default "unspecified-bg" frame)))
(add-hook 'after-make-frame-functions #'on-frame-open)

(setup (:package darkman)
  (:only-if (executable-find "darkman"))
  (setq darkman-themes '(:light neron-light :dark neron-dark))
  (add-hook 'after-init-hook #'darkman-mode)

  (when (daemonp)
    (add-hook 'server-after-make-frame-hook #'darkman-mode)
    (advice-add 'darkman-mode
                :after
                (lambda ()
                  (remove-hook 'server-after-make-frame-hook
                               #'darkman-mode))))

  ;; This wasn't working, so idk :c
  ;; https://darkman.grtcdr.tn/MANUAL.html#:~:text=disabling%20existing%20themes
  (defadvice darkman-set (before no-theme-stacking activate)
    "Disable the previous theme before loading a new one."
    (mapc #'disable-theme custom-enabled-themes)))

(when (eq system-type 'windows-nt)
  (let ((islight (shell-command-to-string "reg query \"HKCU\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize\" /V \"SystemUsesLightTheme\"")))
    (if (string-match-p "0x1" islight)
        (load-theme 'neron-light)
      (load-theme 'neron-dark))))

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

(setup (:package doom-modeline)
  (:hook-into after-init)
  (:option doom-modeline-height 15
           doom-modeline-buffer-encoding nil
           ;; display-time-format '%H:%M'
           doom-modeline-percent-position nil
           doom-modeline-icon nil
           ))

(set-window-margins nil 1)

(setup (:package fira-code-mode)
  (:only-if (display-graphic-p))
  (:hook-into prog-mode)
  (unless (display-graphic-p) ; redundant with :only-if?
    (fira-code-mode -1))
  (with-eval-after-load 'fira-code-mode
    (add-to-list 'fira-code-mode-disabled-ligatures "-}"))
  )

(defun kb/toggle-window-transparency ()
  "Toggle transparency."
  (interactive)
  (let ((alpha-transparency 75))
    (pcase (frame-parameter nil 'alpha-background)
      (alpha-transparency (set-frame-parameter nil 'alpha-background 100))
      (t (set-frame-parameter nil 'alpha-background alpha-transparency)))))
;; (frame-parameter nil 'alpha-background)
;; (set-frame-parameter nil 'alpha-background 75)
;; (set-frame-parameter nil 'alpha-background 90)

;; (lambda () (interactive) (find-alternate-file ".."))
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
         (start-process "" nil "launch" file-path))) file-list)))

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

(setup dired
  (:load-after dired)
  ;; #TODO-test dired-before-readin-hook
  (:package dired-rainbow
            dired-hide-dotfiles
            dired-narrow
            dired-subtree
            dired-efap
            all-the-icons-dired
            diredfl
            ;; dired-single
            ;; joseph-single-dired
            ;; obsoleted by `dired-kill-when-opening-new-dired-buffer'
            )

  (:also-load dired-x dired-aux)
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

  (:also-load dired-rainbow)
  (:with-feature dired-rainbow
    ;; * `dired-rainbow-define` - add face by file extension
    ;; * `dired-rainbow-define-chmod` - add face by file permissions
    (dired-rainbow-define-chmod directory  "#69aaff" "d.*")
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
    (dired-rainbow-define-chmod executable-unix "#61bd09" "-.*x.*")
    ;; How it works:
    ;; After defining `dired-rainbow-define'[-chmod], it creates faces with
    ;; the provided SYMBOLs and FACE-PROPS as the default. Then the faces
    ;; can be individually customized on a theme file, overriding the
    ;; default FACE-PROPS. E.g.:
    ;; For (dired-rainbow-define markdown...), the face `dired-rainbow-markdown-face'
    ;; is created.
    )


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

  ;; dired-efap
  (:bind "r" dired-efap)
  (:with-feature dired-efap
    (:option dired-efap-initial-filename-selection nil))

  (:with-feature all-the-icons-dired
    (:load-after dired)
    (:hook-into dired-mode))

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

(add-to-list 'load-path (concat user-emacs-directory "modes"))

(setup (:package (systemd-mode :type git :host github
                               :repo "pdbrown/systemd-mode"
                               :files ("*.txt" "systemd.el" (:exclude ".git")))))

(setup (:package haskell-mode)
  ;; (:option haskell-process-path-ghci "ghci-9.2.2"  ; this is for ghcup versioned ghc & ghci binaries.
  ;; haskell-process-args-ghci '("-ferror-spans")
  ;; )
  (setq haskell-font-lock-symbols t)

  (:bind "C-c C-v" haskell-cabal-visit-file)
  )
(add-to-list 'auto-mode-alist '("\\(stack\\.yaml\\|package\\.yaml\\)\\'" . haskell-cabal-mode))

(setup (:package yaml-mode))

(setup (:package pkgbuild-mode))

(setup (:package powershell))

(setup (:package (kbd-mode :type git :host github :repo "kmonad/kbd-mode")))

(setup (:package (sxhkd-mode :type git :host github :repo "xFA25E/sxhkd-mode"))
  (add-to-list 'auto-mode-alist `(,(rx "sxhkdrc" string-end) . sxhkd-mode)))

(setup (:package yuck-mode))

(setup (:package tree-sitter tree-sitter-langs tree-sitter-indent)
  (:with-hook (;; after adding a new hook, reboot Emacs for it to work on
               ;; org-mode.
               c-mode-common-hook
               ;; sh-mode-hook
               python-mode-hook
               haskell-mode-hook
               )
    (:hook tree-sitter-hl-mode)))

(setup (:package rainbow-mode)
  (:hook-into css-mode))

(define-minor-mode sensitive-mode
  "For sensitive files like password lists.
It disables backup creation and auto saving.

With no argument, this command toggles the mode.
Non-null prefix argument turns on the mode.
Null prefix argument turns off the mode."
  ;; The initial value.
  :init-value nil
  ;; The indicator for the mode line.
  :lighter " Sensitive"
  ;; The minor mode bindings.
  :keymap nil
  ;; added keywords instead of deprecated positional arguments:
  ;; fix for "Warning: Use keywords rather than deprecated positional
  ;; arguments to `define-minor-mode'" # [2022-11-11 Fri 16:09:40 -03]
  ;; See the commits from [[https://github.com/purcell/emacs.d/issues/780][Use keywords rather than positional arguments to define-minor-mode · Issue #780 · purcell/emacs.d]]

  (if (symbol-value sensitive-mode)
      (progn
        ;; disable backups
        (set (make-local-variable 'backup-inhibited) t)
        ;; disable auto-save
        (if auto-save-default
            (auto-save-mode -1)))
                                        ;resort to default value of backup-inhibited
    (kill-local-variable 'backup-inhibited)
                                        ;resort to default auto save setting
    (if auto-save-default
        (auto-save-mode 1))))

;; 'eshell-output-filter-functions void variable means that eshell has to be
;; started once first.
(setup eshell (:package eshell-git-prompt eshell-syntax-highlighting)
       (:option eshell-hist-ignoredups t
                eshell-scroll-to-bottom-on-input t
                eshell-history-size 10000
                eshell-buffer-maximum-lines 2048)
       (:with-hook eshell-first-time-mode-hook
         (:hook (lambda() (add-hook 'eshell-pre-command-hook 'eshell-save-some-history)
                  (add-to-list 'eshell-output-filter-functions 'eshell-truncate-buffer)))))

(setup term (:package eterm-256color)
       (:option explicit-shell-file-name "bash")
       (:with-mode eterm-256color-mode
         (:hook-into term-mode)))

(setup (:package multi-vterm))

;; Make shebang (#!) file executable when saved
(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

(setup (:package emmet-mode)
  ;; (:with-map emmet-mode-keymap
  ;;     (:bind ))
  (:hook-into html-mode))

(setup css
  (:option css-indent-offset 2))

(setup (:package web-mode)
  ;; (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.php\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.[agj]sp\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.html?\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.scss\\'" . web-mode))
  ;; (add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
  ;; (:hook-into html-mode css-mode)
  (:hook (:option web-mode-markup-indent-offset 2
                  web-mode-css-indent-offset 2
                  web-mode-code-indent-offset 2
                  web-mode-markup-indent-offset 2
                  web-mode-style-padding 2
                  web-mode-script-padding 2
                  web-mode-enable-auto-closing t
                  web-mode-enable-auto-opening t
                  web-mode-enable-auto-pairing t
                  web-mode-enable-auto-indentation t)))

(setup (:package typescript-mode)
  (:option typescript-indent-level 2)
  (:hook-into js-mode-hook))

(setup (:package magit)

  (defvar v/magit-git-global-arguments--bare-git-dir-dotfiles
    (concat "--git-dir=" (expand-file-name "~/.dotfiles/"))
    "Location of the bare git repository to track dotfiles.")

  (defvar v/magit-git-global-arguments--bare-work-tree-dotfiles
    (concat "--work-tree=" (expand-file-name "~"))
    "Location of the bare git repository's work directory to watch for files.")

  ;; use maggit on git bare repos like dotfiles repos, don't forget to
  ;; change `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' to your needs
  (defun f/magit-status-bare-dotfiles ()
    "set --git-dir and --work-tree in `magit-git-global-arguments' to `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' and calls `magit-status'"
    (interactive)
    (require 'magit-git)
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-git-dir-dotfiles)
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-work-tree-dotfiles)
    (call-interactively 'magit-status))

  ;; if you use `f/magit-status-bare-dotfiles' you cant use `magit-status' on
  ;; other other repos you have to unset `--git-dir' and `--work-tree'
  ;; use `f/magit-status' insted as it unsets those before calling
  ;; `magit-status'
  (defun f/magit-status ()
    "removes --git-dir and --work-tree in `magit-git-global-arguments' and calls `magit-status'"
    (interactive)
    (require 'magit-git)
    (setq magit-git-global-arguments (remove v/magit-git-global-arguments--bare-git-dir-dotfiles magit-git-global-arguments))
    (setq magit-git-global-arguments (remove v/magit-git-global-arguments--bare-work-tree-dotfiles magit-git-global-arguments))
    (call-interactively 'magit-status))

  ;; (unbind-key "C-x g") ; unbind default `magit-status'
  (:global
   ;; [remap magit-status] f/magit-status
   "C-x g" f/magit-status
   "C-x d" f/magit-status-bare-dotfiles)


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

  (define-key dired-mode-map (kbd "C-c C-a") #'f/dired-bare-git-add-dotfiles))

(defun f/check-and-convert-line-endings ()
  "Check and convert line endings to LF if necessary."
  (interactive)
  (when (memq buffer-file-coding-system '(utf-8-dos utf-16-dos))
    (set-buffer-file-coding-system 'utf-8-unix t)
    (save-buffer)))

;; (add-hook 'find-file-hook 'f/check-and-convert-line-endings)

(setup (:package htmlize)
  (:option org-html-htmlize-output-type 'css ; 'inline-css
           htmlize-html-charset "utf-8"))

(setup cc-mode
  (electric-pair-local-mode -1) ;; #manual-smartparens
  (smartparens-mode) ;; #manual-smartparens
  )

(defun f/gcc-compile-current-file ()
  "Compile current file with gcc.

Get the current buffer's filename with the function `buffer-file-name' and
using the function `compile' build a command like:
   \"gcc -o filename.c.out /path/to/filename.c\""
  (interactive)
  (defvar-local fullpath-filename (file-truename (buffer-file-name))
    "Get filename of the current buffer")
  (let ((filename (file-name-nondirectory fullpath-filename)))
    (if (string= (file-name-extension filename) "c")
        (compile (concat "gcc -o " (shell-quote-argument
                                    (file-name-base filename)) ".out"
                                    " "
                                    (shell-quote-argument filename))))
    (if (string= (file-name-extension filename) "cpp")
        (compile (concat "g++ -o " (shell-quote-argument
                                    (file-name-base filename)) ".out"
                                    " "
                                    (shell-quote-argument filename)))))
  (message (concat "\"" fullpath-filename ".out\"")))

(add-hook 'compilation-finish-functions
          (lambda (buf strg)
            (let ((win  (get-buffer-window buf 'visible)))
              (when win (delete-window win)))))

(defun f/run-executable-in-floating-terminal (exe-file)
  "Open Alacritty with class=float and run executable EXE-FILE."
  (interactive)
  (message "Opening executable file: " exe-file ".")
  (shell-command
   (concat
    "alacritty --class=float"
    " "
    "--option window.dimensions.columns=\"${w:-80}\""
    " "
    "window.dimensions.lines=\"${h:-20}\""
    " "
    "--command sh -c " (shell-quote-argument
                        (concat exe-file " | bat --paging=always")))))
;; removed --hold bc bat paging holds the terminal until othewise [2022-04-24 Sun 14:41:04]

(defun f/c-comp-and-run()
  "Compile current C/C++ file and run it in the terminal."
  (interactive)
  (f/run-executable-in-floating-terminal
   ;; (f/gcc-compile-current-file v-local/compiled-file-out)
   (f/gcc-compile-current-file)
   ))

(with-eval-after-load 'cc-mode
  (define-key c-mode-base-map (kbd "C-c '") #'f/c-comp-and-run)
  (define-key c-mode-base-map (kbd "C-c C-c") #'f/c-comp-and-run))

(setup (:package rust-mode))
;; rustic

(setup (:package ob-rust)
  (:load-after org)
  (org-babel-do-load-languages
   'org-babel-load-languages
   (append org-babel-load-languages
           '((haskell . t)
             ;; (async   . t) ; from ob-async
             (shell   . t)
             (C       . t))))
  )

(setup (:package lua-mode))

(setup picard-mode)

(setup tex-mode

(:package auctex)

(with-eval-after-load 'ox-html
  (setq org-html-head
        (replace-regexp-in-string
         ".org-svg { width: 90%; }"
         ".org-svg { width: auto; }"
         org-html-style-default)))

) ; end of (setup tex-mode

(setup (:package org-fragtog))

(add-to-list 'load-path (concat user-emacs-directory "elisp"))

(setup server
  (:option server-client-instructions nil)
  (:hook-into after-init))

(setup (:package gptel)
  (:require auth-source) ; seems necessary, for some reason setup.el
                         ; and straght load before it.
  (:option gptel-api-key (auth-source-pick-first-password :host "api.openai.com")
           gptel-default-mode 'org-mode))

(with-system windows-nt
  (setenv "LANG" "en_US")

)
