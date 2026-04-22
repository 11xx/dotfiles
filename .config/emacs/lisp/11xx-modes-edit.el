;; -*- lexical-binding: t; -*-

(use-package systemd
  :vc (:url "https://github.com/pdbrown/systemd-mode"))

(use-package yaml-mode)

;; considering `yaml-ts-mode' is already provided by Emacs
;; use `yaml-indent-line' with it.
(with-eval-after-load 'yaml-ts-mode
  (require 'yaml-mode)
  (add-hook 'yaml-ts-mode-hook
            (lambda ()
              (setq-local indent-line-function #'yaml-indent-line)
              (setq-local yaml-indent-offset 2)))

  (define-advice org-src-font-lock-fontify-block
    (:around (orig lang start end) my/yaml-strip-org-coderefs)
  "Prevent org code refs from breaking tree-sitter YAML fontification."
  (if (not (string-match-p (rx word-start "yaml") lang))
      (funcall orig lang start end)
    (let* ((coderef-re (rx (1+ blank)
                           "(ref:" (1+ (not (any " \t\n)"))) ")"
                           (* blank) eol))
           replacements)
      ;; Phase 1: swap (ref:...) for same-length spaces so TS sees valid YAML
      (with-silent-modifications
        (save-excursion
          (goto-char start)
          (while (re-search-forward coderef-re end t)
            (push (list (match-beginning 0)
                        (match-end 0)
                        (match-string 0))
                  replacements)
            (replace-match
             (make-string (- (match-end 0) (match-beginning 0)) ?\s)
             t t))))
      ;; Phase 2: fontify (TS sees clean YAML), then unconditionally restore
      (unwind-protect
          (funcall orig lang start end)
        (with-silent-modifications
          (save-excursion
            (pcase-dolist (`(,beg ,_end ,str) replacements)
              (goto-char beg)
              (delete-region beg (+ beg (length str)))
              (insert str)
              ;; faces on these positions are now from our spaces; override with comment
              (put-text-property beg (+ beg (length str))
                                 'face 'font-lock-comment-face)))))))))

(use-package pkgbuild-mode
  :hook (pkgbuild-mode . (lambda () (flymake-mode -1))))

(use-package powershell)

(use-package ansible)
(use-package ansible-vault)
(use-package ansible-doc)

(use-package yuck-mode)

(use-package hyprlang-ts-mode
  :mode "*hyprland.conf")

(use-package picard-mode
  :vc (:url "https://codeberg.org/useless-utils/picard-mode" :rev :newest)
  :config
  (use-package picard-ts-mode
    :ensure nil
    :after picard-mode
    :if (treesit-available-p)))

(provide '11xx-modes-edit)
;;; 11xx-modes-edit.el ends here
