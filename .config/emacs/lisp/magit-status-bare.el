;; NOTE: This requires lexical-binding = t  -*- lexical-binding: t; -*-
(require 'magit)
(require 'dired)
(require '11xx-functions) ; filter-list-any-string-prefix

;;;###autoload
(defun magit-status-default ()
  "Wrapper for `magit-status' without \"--git-dir\" or \"--work-tree\" CLI args.

Magit relies on `magit-git-global-arguments' for passing to git
command-line arguments, normally it's not necessary to customize
it but when invoking `magit-status' for a bare git repository is
desired `magit-git-global-arguments' needs to include the
`--git-dir=<dir>' and `--work-tree=<dir>' options. Though there's
a problem with this approach: Customizing
`magit-git-global-arguments' needs to change it globally because
even though `magit-status' may work when called inside a `let',
other commands inside the magit buffer will also read from the
same variable, but if the new values have not been set globally
commands like `magit-stage' will not work because they will be
missing `--git-dir' and `--work-tree'. A hacky way of doing it is
having a version for the bare git function calls that include the
custom flags, and this version that removes the custom
flags. Then replace the keybind for `magit-status'."
  (interactive)
  (setq magit-git-global-arguments (filter-list-any-string-prefix
                                    magit-git-global-arguments
                                    '("--git-dir" "--work-tree")))
  (call-interactively #'magit-status))

;;;###autoload
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
         )
    (setq magit-git-global-arguments (append (eval (car (get 'magit-git-global-arguments 'standard-value)))
                                             (list git-dir-arg work-tree-arg)))

    (if (key-valid-p key-binding)
        (keymap-global-set key-binding
                           (let ((expanded-git-dir git-dir)
                                 (expanded-work-tree work-tree))
                             (lambda ()
                               (interactive)
                               (magit-status-bare :git-dir expanded-git-dir :work-tree expanded-work-tree))))
      (call-interactively 'magit-status))))

;;;###autoload
(defun dired-git-add-bare (&rest args)
  "Add files to a bare repository from Dired using ARGS.

ARGS is a property list that supports the following keys:
- `:git-dir'       (required) The absolute path to the bare Git directory.
- `:work-tree'     (required) The absolute path to the repository's worktree.
- `:key-bind'      (optional) Set a key binding to invoke this
  function in `dired-mode-map'. If provided, the key binding is
  set, but the function is not executed."
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
                      (dired-git-add-bare :git-dir git-dir :work-tree work-tree)))
      ;; Execute the function
      (let* ((files (dired-get-marked-files nil nil))
             (git-cmd (mapconcat 'identity (list "git" git-dir-arg work-tree-arg) " "))
             (output (mapconcat (lambda (file)
                                  (shell-command-to-string
                                   (concat git-cmd " add --verbose " (shell-quote-argument file))))
                                files "\n")))
        (message "Git add command completed:\n%s" output)))))


(provide 'magit-status-bare)
