;; -*- lexical-binding: t; -*-
(use-package vertico
  :bind (:map vertico-map
              ("?" . minibuffer-completion-help)
              ("M-RET" . minibuffer-force-complete-and-exit)
              ("M-TAB" . minibuffer-complete)
              ("M-<backspace>" . minibuffer-backward-delete-word)
              ("M-D" . minibuffer-backward-delete-word)
              ("C-M-d" . backward-delete-char)
              ("M-d" . minibuffer-delete-word)
              ("C-k" . minibuffer-delete-line)
              ("C-M-k" . kill-line))
  :init
  (defun minibuffer-backward-delete-word (arg)
    "Delete characters backward until encountering the beginning of a word.
With argument ARG, do this that many times."
    (interactive "p")
    (delete-region (point) (progn (backward-word arg) (point))))

  (defun minibuffer-delete-word (arg)
    "Delete characters forward until the end of a word.
Like `kill-word' but doesn't add deleted words to kill ring."
    (interactive "p")
    (delete-region (point) (progn (forward-word arg) (point))))

  (defun minibuffer-delete-line (arg)
    "Delete characters forward until the end of the line.
Like `kill-line' but doesn't add deleted characters to kill ring."
    (interactive "p")
    (delete-region (point) (progn (end-of-line arg) (point))))

  (setq vertico-scroll-margin 4
        vertico-cycle t
        read-extended-command-predicate #'command-completion-default-include-p
        enable-recursive-minibuffers t
        completion-cycle-threshold 3
        minibuffer-prompt-properties '(read-only t cursor-intangible t face minibuffer-prompt))
  :hook ((minibuffer-setup . cursor-intangible-mode)
         (after-init . vertico-mode)))
;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :ensure nil
  :init
  (setq savehist-additional-variables '(kill-ring compile-command search-ring regexp-search-ring)
        history-length 1000
        history-delete-duplicates t)
  :config
  (put 'savehist-minibuffer-history-variables 'history-length 1000)
  (put 'org-read-date-history 'history-length 1000)
  (put 'read-expression-history 'history-length 1000)
  (put 'org-table-formula-history 'history-length 1000)
  (put 'extended-command-history 'history-length 1000)
  (put 'ido-file-history 'history-length 1000)
  (put 'helm-M-x-input-history 'history-length 1000)
  (put 'minibuffer-history 'history-length 1000)
  (put 'ido-buffer-history 'history-length 1000)
  (put 'buffer-name-history 'history-length 1000)
  (put 'file-name-history 'history-length 1000)
  :hook (after-init . savehist-mode))
(use-package orderless
  :init
  (setq completion-category-defaults nil
        completion-styles '(orderless initials substring basic)
        completion-category-overrides '((file (styles basic partial-completion)))
        orderless-component-separator "[ &]"
        orderless-smart-case t)
  :config
  (defun just-one-face (fn &rest args)
    (let ((orderless-match-faces [completions-common-part]))
      (apply fn args)))
  (advice-add 'company-capf--candidates :around #'just-one-face))
;; Enable richer annotations using the Marginalia package
(use-package marginalia
  :hook (after-init . marginalia-mode)
  :bind (:map minibuffer-local-map ("M-A" . marginalia-cycle))
  :init
  (setq marginalia-align 'left
        marginalia-field-width 120))
(use-package consult
  :bind (("C-s" . consult-line)
         ("C-x b" . consult-buffer)
         ("C-r" . consult-history)
         ("C-c o s" . consult-org-heading)))
;; note: consult-outline & consult-org-heading
(use-package embark
  :after consult
  :bind (("C-." . embark-act)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command)
  :config
  (add-to-list 'display-buffer-alist
               '("\\`\\*Embark Collect \\(Live\\|Completions\\)\\*"
                 nil
                 (window-parameters (mode-line-format . none)))))

(use-package embark-consult
  :after embark)
(use-package corfu
  :bind (("<tab>" . completion-at-point))
  :bind (:map corfu-map
              ("M-SPC" . corfu-insert-separator)
              ([remap next-line] . nil)
              ([remap previous-line] . nil))
  :init
  (setq corfu-cycle t
        corfu-auto-delay 0.1
        corfu-auto-prefix 4
        corfu-preview-current nil)
  :hook (after-init . global-corfu-mode)
  :config
  (global-corfu-mode 1)
  (defun corfu-enable-in-minibuffer ()
    "Enable Corfu in the minibuffer if `completion-at-point' is bound."
    (when (where-is-internal #'completion-at-point (list (current-local-map)))
      (setq-local corfu-echo-delay nil
                  corfu-popupinfo-delay nil)
      (corfu-mode 1)))
  (add-hook 'minibuffer-setup-hook #'corfu-enable-in-minibuffer))

(use-package corfu-terminal
  :after corfu
  :config
  (unless (display-graphic-p)
    (corfu-terminal-mode 1)))
(use-package prescient
  :after corfu
  :config
  (prescient-persist-mode 1))

(use-package corfu-prescient
  :after corfu
  :hook (corfu-mode . corfu-prescient-mode))
;; Add extensions
(use-package cape
  :config
  ;; Bind dedicated completion commands
  ;; Alternative prefix keys: C-c p, M-p, M-+, ...
  ;; (:global-set
  ;;  "C-c p p" completion-at-point ;; capf
  ;;  "C-c p t" complete-tag        ;; etags
  ;;  "C-c p d" cape-dabbrev        ;; or dabbrev-completion
  ;;  "C-c p h" cape-history
  ;;  "C-c p f" cape-file
  ;;  "C-c p k" cape-keyword
  ;;  "C-c p s" cape-elisp-symbol
  ;;  "C-c p e" cape-elisp-block
  ;;  "C-c p a" cape-abbrev
  ;;  "C-c p l" cape-line
  ;;  "C-c p w" cape-dict
  ;;  "C-c p :" cape-emoji
  ;;  "C-c p \\" cape-tex
  ;;  "C-c p _" cape-tex
  ;;  "C-c p ^" cape-tex
  ;;  "C-c p &" cape-sgml
  ;;  "C-c p r" cape-rfc1345)
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
(use-package tempel
  :bind (("M-+" . tempel-complete)
         ("M-*" . tempel-insert))
  :init
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
  :hook ((prog-mode . tempel-setup-capf)
         (text-mode . tempel-setup-capf)))
(setq lsp-use-plists t)

(use-package lsp-ui)
(use-package lsp-mode
  :init
  (setq lsp-idle-delay 0.1
        lsp-keymap-prefix "C-c l"
        lsp-log-io nil))
(use-package flycheck)
(use-package eldoc-box
  :init
  (setq eldoc-box-doc-separator (concat "\n\n" (make-string 3 ?-) "\n\n")
        eldoc-box-clear-with-C-g t
        eldoc-box-max-pixel-height 1400)
  :config
  (add-hook 'eldoc-box-buffer-hook
            (lambda () (setq-local show-trailing-whitespace nil))))

(use-package eglot
  :ensure nil
  :init
  (setq eglot-send-changes-idle-time 0.01
        eldoc-idle-delay 0.01
        eldoc-echo-area-prefer-doc-buffer t))

(provide '11xx-completion)
