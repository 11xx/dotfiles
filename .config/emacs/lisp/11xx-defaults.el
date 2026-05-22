;; -*- lexical-binding: t; -*-

(keymap-global-set "C-c C-/" #'comment-region)
(keymap-global-set "C-c C-M-/" #'uncomment-region)
(keymap-global-set "<remap> <mark-word>" #'mark-whole-word)
(keymap-global-set "C-c a f v" #'add-file-local-variable)
(keymap-global-set "C-c d f v" #'delete-file-local-variable)
(keymap-global-set "C-c a f p" #'add-file-local-variable-prop-line)
(keymap-global-set "C-c d f p" #'delete-file-local-variable-prop-line)
(keymap-global-set "C-c C-M-t" #'visual-line-mode)
(keymap-global-set "C-c M-t" #'toggle-truncate-lines)
(keymap-global-set "C-x C-z" #'org-set-property)
(keymap-global-set "C-z" #'org-set-property)
(keymap-global-set "C-S-<left>" #'shrink-window-horizontally)
(keymap-global-set "C-S-<right>" #'enlarge-window-horizontally)
(keymap-global-set "C-S-<down>" #'shrink-window)
(keymap-global-set "C-S-<up>" #'enlarge-window)
(keymap-global-set "C-M-d" #'delete-pair)
(keymap-global-set "M-D" #'delete-pair)
(keymap-global-set "M-." #'forward-list)
(keymap-global-set "M-," #'backward-list)
(keymap-global-set "C-M-." #'down-list)
(keymap-global-set "C-M-," #'backward-up-list)

(put 'narrow-to-region 'disabled nil)
(put 'narrow-to-page 'disabled nil)
(put 'narrow-to-defun 'disabled nil)
(put 'widen 'disabled nil)
(put 'downcase-region 'disabled nil)

(add-function :after after-focus-change-function
              (lambda () (save-some-buffers t)))

(save-place-mode 1)
(delete-selection-mode 1)
(electric-pair-mode 1)
(electric-indent-mode 1)

(use-package whitespace
  :hook ((prog-mode . whitespace-mode)
         (text-mode . whitespace-mode))
  :init
  (setq whitespace-style '(face tabs missing-newline-at-eof)
        show-trailing-whitespace t)
  :config
  (dolist (hook '(special-mode-hook
                  term-mode-hook
                  vterm-mode-hook
                  comint-mode-hook
                  compilation-mode-hook
                  minibuffer-setup-hook
                  minibuffer-mode-hook
                  calendar-mode-hook
                  eshell-mode-hook
                  completion-list-mode-hook
                  messages-buffer-mode-hook
                  diff-mode-hook))
    (add-hook hook (lambda () (setq-local show-trailing-whitespace nil)))))

(add-hook 'after-init-hook #'global-superword-mode)

(use-package ace-window
  :bind (("M-o" . ace-window))
  :init
  (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l)
        aw-scope 'frame))

;; new remap format is "<remap> <what-to-remap>" #'my-function
(use-package helpful
  :bind (("<remap> <describe-function>" . helpful-callable)
         ("<remap> <describe-command>" . helpful-command)
         ("<remap> <describe-variable>" . helpful-variable)
         ("<remap> <describe-key>" . helpful-key)
         ("<remap> <describe-symbol>" . helpful-symbol)))

(use-package which-key
  :init
  (setq which-key-idle-delay 2.0))


(use-package jump-char
  :after kmacro
  :bind (("C-c j f" . jump-char-forward)
         ("C-c j b" . jump-char-backward)
         ("C-c j m f" . jump-char-forward-set-mark)
         ("C-c j m b" . jump-char-backward-set-mark)))

(use-package delight)

(setopt ispell-dictionary "en_GB")

(defun endless/org-ispell ()
  "Configure `ispell-skip-region-alist' for `org-mode'."
  (make-local-variable 'ispell-skip-region-alist)
  (add-to-list 'ispell-skip-region-alist '(org-property-drawer-re))
  (add-to-list 'ispell-skip-region-alist '("~" "~"))
  (add-to-list 'ispell-skip-region-alist '("=" "="))
  (add-to-list 'ispell-skip-region-alist '("^#\\+BEGIN_SRC" . "^#\\+END_SRC")))
(add-hook 'org-mode-hook #'endless/org-ispell)

(setq custom-file (expand-file-name "custom.el" no-littering-var-directory))

(defun check-file-touch (file)
  "Check if FILE exists and create it if it doesn't.
It uses `make-empty-file' PARENTS argument 't'."
  (if (not (file-exists-p file))
      (make-empty-file file)))

(check-file-touch custom-file)

(load custom-file 'noerror 'nomessage)

(use-package async)

(use-package detached
  :bind (("<remap> <async-shell-command>" . detached-shell-command)
         ("<remap> <compile>" . detached-compile)
         ("<remap> <recompile>" . detached-compile-recompile)
         ("<remap> <detached-open-session>" . detached-consult-session))
  :init
  (setq detached-show-output-on-attach t)
  :config
  (detached-init))

(use-package tramp
  :ensure nil
  :config
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path))

(use-package desktop
  :ensure nil
  :init
  (defvar 11xx--daemon-name
    (let ((d (daemonp)))
      (cond
       ((stringp d) d)
       ((eq d t)   "default")
       (t           nil)))
    "Server name this Emacs instance is running as, or nil if not a daemon.
Mirrors `daemonp': a string for named daemons (--daemon=NAME), \"default\"
for unnamed (--daemon), nil for interactive sessions.")

  :config
  (when 11xx--daemon-name
    (setq desktop-base-file-name (format ".emacs-%s.desktop" 11xx--daemon-name)
          desktop-base-lock-name (format ".emacs-%s.desktop.lock" 11xx--daemon-name)))

  (setq desktop-dirname (expand-file-name "desktop/" no-littering-var-directory)
        desktop-auto-save-timeout 1
        desktop-save 'ask-if-new)
  (desktop-save-mode))

(use-package eros
  :hook (org-mode . eros-mode)
  :init
  (setq eros-eval-result-duration 'command
        eros-overlays-use-font-lock t))

(provide '11xx-defaults)
;;; 11xx-defaults.el ends here
