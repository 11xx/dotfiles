(add-to-list 'load-path (concat user-emacs-directory "modes"))
(setup (:package (systemd :url "https://github.com/pdbrown/systemd-mode")))
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
(setup (:package yuck-mode))
;; #TODO use builtin tree-sitter
;; (setup tree-sitter
;;        (:package tree-sitter-langs tree-sitter-indent)
;;   (:with-hook (;; after adding a new hook, reboot Emacs for it to work on
;;                ;; org-mode.
;;                c-mode-common-hook
;;                ;; sh-mode-hook
;;                python-mode-hook
;;                haskell-mode-hook)
;;     (:hook tree-sitter-hl-mode)))
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
       (setopt eshell-hist-ignoredups t
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
(setup cc-mode
  (:disabled)
  ;; (electric-pair-local-mode -1) ;; #manual-smartparens
  ;; (smartparens-mode) ;; #manual-smartparens
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

(provide '11xx-modes)
