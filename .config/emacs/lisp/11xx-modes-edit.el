;; -*- lexical-binding: t; -*-

(setup (:elpaca systemd :host github :repo "pdbrown/systemd-mode"))

(elpaca yaml-mode)
(elpaca-wait)

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

(setup (:elpaca pkgbuild-mode)
  (add-hook 'pkgbuild-mode-hook (lambda() (flymake-mode -1))))

(setup (:elpaca powershell))

(setup (:elpaca ansible))
(setup (:elpaca ansible-vault))
(setup (:elpaca ansible-doc))

(setup (:elpaca yuck-mode))

(setup (:elpaca hyprlang-ts-mode)
  (:autoload hyprlang-ts-mode)
  (:match-file "*hyprland.conf"))

(setup picard-mode)

(provide '11xx-modes-edit)
;;; 11xx-modes-edit.el ends here
