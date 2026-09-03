;; -*- lexical-binding: t; -*-
(require 'magit-status-bare)

(use-package magit
  :defer t
  :init
  (keymap-global-unset "C-x g")
  (keymap-global-set "C-x g g" #'magit-status-default)
  (magit-status-bare :git-dir "~/.local/dotfiles.git/"
                     :work-tree (getenv "HOME")
                     :key-bind "C-x g d")
  (dired-git-add-bare :git-dir "~/.local/dotfiles.git/"
                      :work-tree (getenv "HOME")
                      :key-bind "C-c g d a"))

(with-eval-after-load 'dired
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
  (keymap-set dired-mode-map "C-c g g a" #'dired-git-add))

(require '11xx-vot)

(provide '11xx-magit)
