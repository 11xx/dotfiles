;; NOTE: This requires lexical-binding = t  -*- lexical-binding: t; -*-
(require 'magit)
(require 'dired)

(defun magit-status-bare (&rest args)
  "Configure Magit to operate on a bare repository using ARGS.

ARGS is a property list that supports the following keys:
- `:git-dir'     (required) Path to a bare Git directory.
- `:work-tree'   (required) Path to the repository's worktree.
- `:key-bind'    (optional) Set a global key binding. If
  provided, the key binding is set, but the function is not
  executed."
  (interactive)
  (let* ((git-dir (plist-get args :git-dir))
         (work-tree (plist-get args :work-tree))
         (key-binding (plist-get args :key-bind))
         (git-dir-arg (concat "--git-dir=" (expand-file-name git-dir)))
         (work-tree-arg (concat "--work-tree=" (expand-file-name work-tree)))
         (magit-git-global-arguments (append (eval (car (get 'magit-git-global-arguments 'standard-value)))
                                             (list git-dir-arg work-tree-arg))))

    (if (key-valid-p key-binding)
        (keymap-global-set key-binding
                           (let ((expanded-git-dir git-dir)
                                 (expanded-work-tree work-tree))
                             (lambda ()
                               (interactive)
                               (magit-status-bare :git-dir expanded-git-dir :work-tree expanded-work-tree))))
      (call-interactively 'magit-status))))

(defun dired-bare-git-add (&rest args)
  "Add files to a bare repository from Dired using ARGS.

ARGS is a property list that supports the following keys:
- `:git-dir'       (required) The absolute path to the bare Git directory.
- `:work-tree'     (required) The absolute path to the repository's worktree.
- `:key-bind'      (optional) A key binding to invoke this function
  in `dired-mode-map`. If provided, the key binding is set, but
  the function is not executed."
  (interactive)
  (let* ((git-dir (plist-get args :git-dir))
         (work-tree (plist-get args :work-tree))
         (key-binding (plist-get args :key-bind))
         (git-dir-arg (concat "--git-dir=" (expand-file-name git-dir)))
         (work-tree-arg (concat "--work-tree=" (expand-file-name work-tree))))

    (if (key-valid-p key-binding)
        ;; Set the key binding without executing the function
        (keymap-set dired-mode-map key-binding
                    (lambda (&optional arg)
                      (interactive "P")
                      (dired-bare-git-add :git-dir git-dir :work-tree work-tree)))
      ;; Execute the function
      (let* ((files (dired-get-marked-files nil nil))
             (git-cmd (mapconcat 'identity (list "git" git-dir-arg work-tree-arg) " "))
             (output (mapconcat (lambda (file)
                                  (shell-command-to-string
                                   (concat git-cmd " add --verbose " (shell-quote-argument file))))
                                files "\n")))
        (message "Git add command completed:\n%s" output)))))


(provide 'magit-status-bare)
