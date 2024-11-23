;; -*- lexical-binding: t; -*-
(require 'magit)
(require 'dired)

(defun magit-status-bare (&rest args)
  "Setup Magit for a bare repository using ARGS.
ARGS should include:
- :git-dir (required) - The path to the bare Git directory.
- :work-tree (required) - The path to the work tree.
- :key-binding (optional) - Key binding for invoking this function."
  (interactive)
  (let* ((git-dir (plist-get args :git-dir))
         (work-tree (plist-get args :work-tree))
         (key-binding (plist-get args :key-binding))
         (git-dir-arg (concat "--git-dir=" (expand-file-name git-dir)))
         (work-tree-arg (concat "--work-tree=" (expand-file-name work-tree)))
         (magit-git-global-arguments (append (eval (car (get 'magit-git-global-arguments 'standard-value)))
                                             (list git-dir-arg work-tree-arg))))

    (when key-binding
      (keymap-global-set key-binding (lambda () (interactive) (magit-status-bare :git-dir git-dir :work-tree work-tree))))
    (call-interactively 'magit-status)))

(defun dired-bare-git-add (&rest args)
  "Add files to a bare repository from Dired using ARGS.
ARGS should include:
- :git-dir (required) - The path to the bare Git directory.
- :work-tree (required) - The path to the work tree.
- :key-binding (optional) - Key binding for invoking this function in `dired-mode-map`."
  (interactive)
  (let* ((git-dir (plist-get args :git-dir))
         (work-tree (plist-get args :work-tree))
         (key-binding (plist-get args :key-binding))
         (git-dir-arg (concat "--git-dir=" (expand-file-name git-dir)))
         (work-tree-arg (concat "--work-tree=" (expand-file-name work-tree))))
    (when key-binding
      (keymap-set dired-mode-map key-binding
                  (lambda (&optional arg)
                    (interactive "P")
                    (let* ((files (dired-get-marked-files nil arg))
                           (git-cmd (mapconcat 'identity (list "git" git-dir-arg work-tree-arg) " "))
                           (output (mapconcat (lambda (file)
                                                (shell-command-to-string
                                                 (concat git-cmd " add --verbose " (shell-quote-argument file))))
                                              files "\n")))
                      (message "Git add command completed:\n%s" output)))))))

(provide 'magit-bare-status)
