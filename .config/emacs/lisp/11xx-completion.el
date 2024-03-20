(require '11xx-setup)

(setup (:package vertico)
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

  (setopt read-extended-command-predicate #'command-completion-default-include-p
          enable-recursive-minibuffers t
          completion-cycle-threshold 3 ; TAB cycle if there are only few candidates
          ;; Do not allow the cursor in the minibuffer prompt
          minibuffer-prompt-properties '(read-only
                                         t
                                         cursor-intangible
                                         t face minibuffer-prompt))

  (:with-hook after-init-hook
    (:hook vertico-mode)))
(setopt read-extended-command-predicate #'command-completion-default-include-p
        enable-recursive-minibuffers t
        completion-cycle-threshold 3 ; TAB cycle if there are only few candidates
        ;; Do not allow the cursor in the minibuffer prompt
        minibuffer-prompt-properties '(read-only
                                       t
                                       cursor-intangible
                                       t face minibuffer-prompt))
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
    (:bind "M-A" marginalia-cycle))
  (setopt marginalia-align 'left
          marginalia-field-width 120))
(setup (:package consult)
  (:global "C-s" consult-line ;; Was search-forward
           "C-x b" consult-buffer ;; Was switch-to-buffer
           "C-r" consult-history ;; #TODO-ithink was isearch-backward
           "C-c o s" consult-org-heading
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
  ;; (:hook embark-collect-mode consult-preview-at-point-mode)
  )
(setup (:package corfu
                 corfu-terminal)

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

  ;; (:with-hook after-init-hook
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
(setup (:package prescient corfu-prescient)
  (:load-after corfu)
  (:with-hook corfu-mode-hook
    (:hook corfu-prescient-mode))
  (:option prescient-persist-mode t))
;; Add extensions
(use-package cape
  :ensure t
  ;; Bind dedicated completion commands
  ;; Alternative prefix keys: C-c p, M-p, M-+, ...
  :bind (("C-c p p" . completion-at-point) ;; capf
         ("C-c p t" . complete-tag)        ;; etags
         ("C-c p d" . cape-dabbrev)        ;; or dabbrev-completion
         ("C-c p h" . cape-history)
         ("C-c p f" . cape-file)
         ("C-c p k" . cape-keyword)
         ("C-c p s" . cape-elisp-symbol)
         ("C-c p e" . cape-elisp-block)
         ("C-c p a" . cape-abbrev)
         ("C-c p l" . cape-line)
         ("C-c p w" . cape-dict)
         ("C-c p :" . cape-emoji)
         ("C-c p \\" . cape-tex)
         ("C-c p _" . cape-tex)
         ("C-c p ^" . cape-tex)
         ("C-c p &" . cape-sgml)
         ("C-c p r" . cape-rfc1345))
  :init
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
(setup (:package yasnippet)
  (:hide-mode yas-minor-mode)
  (:package haskell-snippets)
  (yas-global-mode))
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
  (:package lsp-haskell)

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

(provide '11xx-completion)
