;; -*- lexical-binding: t; -*-
(setup (:elpaca transient)) ; keyboard menu for magit.
(setup (:elpaca magit)
  (defun dired-git-add (&optional arg)
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
  (keymap-set dired-mode-map "C-c g g a" #'dired-git-add)

  (:with-feature magit-status-bare
    (require 'magit-status-bare)

    (keymap-global-unset "C-x g") ; unbind default `magit-status'
    (:global "C-x g g" magit-status-default)

    (magit-status-bare :git-dir "~/.local/dotfiles.git/"
                       :work-tree (getenv "HOME")
                       :key-bind "C-x g d")
    (dired-git-add-bare :git-dir "~/.local/dotfiles.git/"
                        :work-tree (getenv "HOME")
                        :key-bind "C-c g d a")
    (require '11xx-vot)))

(provide '11xx-magit)
