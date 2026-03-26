;; -*- lexical-binding: t; -*-
(setup magit
  (:elpaca magit)

  ;; rely on autoloads from elpaca block so magit don't need to be required
  ;; inside `magit-status-bare.el'.
  (require 'magit-status-bare)

  ;; unbind default `magit-status' so g can be used as prefix
  (keymap-global-unset "C-x g")

  (keymap-global-set "C-x g g" #'magit-status-default) ; magit-status

  ;;; bare repos
  (magit-status-bare :git-dir "~/.local/dotfiles.git/"
                     :work-tree (getenv "HOME")
                     :key-bind "C-x g d")
  (dired-git-add-bare :git-dir "~/.local/dotfiles.git/"
                      :work-tree (getenv "HOME")
                      :key-bind "C-c g d a")

  (:with-feature dired
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
    (:bind "C-c g g a" dired-git-add))

  (require '11xx-vot))

(setup (:elpaca transient)
  (:load-after magit))

(provide '11xx-magit)
