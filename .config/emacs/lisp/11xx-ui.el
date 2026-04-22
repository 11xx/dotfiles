;;; UI  -*- lexical-binding: t; -*-
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
(defvar 11xx--get-default-font
  (if (eq system-type 'windows-nt)
      ;; "Consolas"
      ;; "Literation Mono Nerd Font" on Linux or "LiterationMono Nerd Font" on (Windows-NT)
      "LiterationMono Nerd Font"
    "Literation Mono Nerd Font")
  "Sets the default font based on the system type.
To be used with `set-font'.")

(defvar 11xx--get-default-font-size
  (if (eq system-type 'windows-nt)
      11
    11)
  "Sets the default font size based on the system type.
To be used with `set-font'.")

(defun set-font (&rest args)
  "Set font face using `set-face-attribute' and keywords.
Available keywords are:

`:name' = a string with the font name like \"Liberation Mono\" or
\"DejaVu Sans Mono\". It defaults to the value from the helper
    function `11xx--get-default-font' that returns a string.

`:size' = a number that is multiplied by 10 internally to pass as
\":height\" to `set-face-attribute'. It defaults to the value
  from the helper function `11xx--get-default-font-size' that returns a
number."
  (let* ((font (or (plist-get args :name) 11xx--get-default-font))
         (size (or (plist-get args :size) 11xx--get-default-font-size)))
    (set-face-attribute 'default nil
                        :font font
                        :height (* size 10))))

(if (daemonp) ;; Load font after daemon frame is created/init hook
    (add-hook 'after-make-frame-functions
              (lambda (frame)
                (with-selected-frame frame
                  (set-font))))
  (add-hook 'after-init-hook
            (lambda () (set-font))))
;; end set font
(setopt cursor-type 'box
        ;; display-line-numbers-type 'relative
        linum-relative-current-symbol ""
        inhibit-startup-screen t
        auto-hscroll-mode 'current-line ; nano-like line horizontal scrolling ; https://emacs.stackexchange.com/questions/40864/scroll-only-current-line-when-truncating-lines
        use-dialog-box nil)
(setq display-line-numbers-grow-only t)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)
(add-hook 'text-mode-hook #'display-line-numbers-mode)
(add-hook 'html-mode-hook #'display-line-numbers-mode)
(dolist (hook '(term-mode-hook
                shell-mode-hook
                eshell-mode-hook
                org-mode-hook))
  (add-hook hook (lambda () (display-line-numbers-mode -1))))
(setopt show-paren-mode t
        show-paren-delay 0.01
        show-paren-style 'parenthesis)

(use-package rainbow-delimiters
  :hook (emacs-lisp-mode . rainbow-delimiters-mode))
(let ((themedir (expand-file-name "themes/" user-emacs-directory)))
  (add-to-list 'custom-theme-load-path themedir)
  (add-to-list 'load-path themedir))
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
(use-package neron-themes
  :load-path "~/code/emacs/neron-themes")

(use-package auto-dark
  :init
  (setq auto-dark-themes '((neron-dark)
                           (neron-light)))
  :config
  (auto-dark-mode)
  (setq minor-mode-alist
        (delq (assq 'auto-dark-mode minor-mode-alist) minor-mode-alist)))
(use-package ibuffer
  :ensure nil
  :bind (("C-x C-b" . ibuffer))
  :hook (ibuffer-mode . (lambda () (ibuffer-switch-to-saved-filter-groups "default")))
  :init
  (setq ibuffer-show-empty-filter-groups nil
        ibuffer-saved-filter-groups
        '(("default"
           ("shell" (mode . shell-mode))
           ("dired" (mode . dired-mode))
           ("org" (mode . org-mode))
           ("emacs-lisp" (mode . emacs-lisp))))
        ibuffer-expert t))
(setq display-fill-column-indicator-column 79)
(add-hook 'prog-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'text-mode-hook #'display-fill-column-indicator-mode)
(add-hook 'prog-mode-hook
          (lambda () (setq-local display-fill-column-indicator-column 120)))
(use-package doom-modeline
  :hook (after-init . doom-modeline-mode)
  :init
  (setq doom-modeline-height 15
        doom-modeline-buffer-encoding nil
        doom-modeline-percent-position nil
        doom-modeline-icon nil
        doom-modeline-enable-word-count nil
        doom-modeline-buffer-file-name-style 'truncate-nil))
(set-window-margins nil 5 5)

(provide '11xx-ui)
