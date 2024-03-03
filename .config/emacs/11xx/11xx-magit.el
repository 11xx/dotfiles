(setup (:package magit)
  (defvar v/magit-git-global-arguments--bare-git-dir-dotfiles
    (concat "--git-dir=" (expand-file-name "~/.local/dotfiles.git/"))
    "Git command argument pointing to the location of the bare git repository to track dotfiles.")

  (defvar v/magit-git-global-arguments--bare-work-tree-dotfiles
    (concat "--work-tree=" (expand-file-name "~"))
    "Git command argument location of the git repository's work directory to track files.")

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


  (:load-after dired)
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

  (define-key dired-mode-map (kbd "C-c d a") #'f/dired-bare-git-add-dotfiles)

  ;; for normal git actions
  ;; **** Git add to bare repo from dired
  (defun f/dired-git-add (&optional arg)
    "Execute 'git add' command for current or marked files in Dired mode.
With prefix ARG, prompt for additional arguments to pass to the command."
    (interactive "P")
    (let* ((files (dired-get-marked-files nil arg))
           (git-cmd "git")
           (output (mapconcat (lambda (file)
                                (shell-command-to-string
                                 (concat git-cmd " add --verbose " (shell-quote-argument file))))
                              files
                              "\n")))
      (message "Git add command completed:\n%s" output)))

  (define-key dired-mode-map (kbd "C-c g a") #'f/dired-git-add)
  )
(defun f/check-and-convert-line-endings ()
  "Check and convert line endings to LF if necessary."
  (interactive)
  (when (memq buffer-file-coding-system '(utf-8-dos utf-16-dos))
    (set-buffer-file-coding-system 'utf-8-unix t)
    (save-buffer)))

;; (add-hook 'find-file-hook 'f/check-and-convert-line-endings)

(provide '11xx-magit)
