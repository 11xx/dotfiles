(setup (:elpaca magit)
  ;; For dotfiles
  (defvar v/magit-git-global-arguments--bare-git-dir-dotfiles
    (concat "--git-dir=" (expand-file-name "~/.local/dotfiles.git/"))
    "Git command argument pointing to the location of the bare git repository to track dotfiles.")

  (defvar v/magit-git-global-arguments--bare-work-tree-dotfiles
    (concat "--work-tree=" (expand-file-name "~"))
    "Git command argument location of the git repository's work directory to track files.")

  (defvar v/magit-git-global-arguments--remove-list
    (list v/magit-git-global-arguments--bare-git-dir-dotfiles
          v/magit-git-global-arguments--bare-work-tree-dotfiles)
    "List containing variables to be removed when running
`magit-status' with custom `magit-git-global-arguments'.")

  ;; use maggit on git bare repos like dotfiles repos, don't forget to
  ;; change `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' to your needs
  (defun f/magit-status-bare-dotfiles ()
    "set --git-dir and --work-tree in `magit-git-global-arguments' to `v/magit-git-global-arguments--bare-git-dir-dotfiles' and `v/magit-git-global-arguments--bare-work-tree-dotfiles' and calls `magit-status'"
    (interactive)
    (require 'magit-git)

    ;; Cleanup before adding again in case another function similar to
    ;; this one but with different arguments was used previously.
    (dolist (var v/magit-git-global-arguments--remove-list)
      (when var
        (setq magit-git-global-arguments (remove var magit-git-global-arguments))))
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-git-dir-dotfiles)
    (add-to-list 'magit-git-global-arguments v/magit-git-global-arguments--bare-work-tree-dotfiles)
    (call-interactively 'magit-status))

  (defun f/magit-status ()
    "Removes --git-dir and --work-tree in `magit-git-global-arguments' and calls `magit-status'."
    (interactive)
    (require 'magit-git)
    (dolist (var v/magit-git-global-arguments--remove-list)
      (when var
        (setq magit-git-global-arguments (remove var magit-git-global-arguments))))
    (call-interactively 'magit-status))

  (keymap-global-unset "C-x g") ; unbind default `magit-status'
  (:global
   ;; [remap magit-status] f/magit-status
   "C-x g g" f/magit-status
   "C-x g d" f/magit-status-bare-dotfiles)

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

  (keymap-set dired-mode-map "C-c g d a" #'f/dired-bare-git-add-dotfiles)
  (keymap-set dired-mode-map "C-c g g a" #'f/dired-git-add)

  (require '11xx-vot))

(provide '11xx-magit)
