;; -*- lexical-binding: t; -*-
(defun dired-find-alternate-file-up ()
  "Sames as `dired-find-alternate-file' but go up one directory instead."
  (interactive)
  (find-alternate-file ".."))
(defun mu-open-in-external-app ()
  "Open the file where point is or the marked files in Dired in external app.

The app is chosen from your OS's preference."
  (interactive)
  (let* ((file-list
          (dired-get-marked-files)))
    (mapc
     (lambda (file-path)
       (let ((process-connection-type nil))
         (start-process "" nil "launch" file-path)))
     file-list)))
;; default terminal application path
(defvar 11xx--terminal (getenv "TERMINAL")
  "The default terminal as in the TERMINAL environment variable.")
;;; function to open new terminal window at current directory
(defun tmtxt/open-current-dir-in-terminal ()
  "Open current directory in 'dired-mode' in terminal application."
  (interactive)
  (shell-command (concat
                  (shell-quote-argument 11xx--terminal)
                  " "
                  "--working-directory"
                  " "
                  (shell-quote-argument (file-truename default-directory)))))

;; (define-key dired-mode-map (kbd "<f4>") 'tmtxt/open-current-dir-in-terminal) ;; was kmacro-end-or-call-macro
(setup ls-lisp
  (setopt ls-lisp-use-insert-directory-program nil
          ls-lisp-dirs-first t
          ls-lisp-ignore-case t
          ls-lisp-use-string-collate nil
          dired-use-ls-dired nil
          dired-listing-switches "-lAhv"
          ;; dired-listing-switches "-l --almost-all --human-readable --group-directories-first --no-group --sort=version"
          ls-lisp-format-time-list '("%Y-%m-%d %H:%M" "%Y-%m-%d %H:%M")
          ls-lisp-use-localized-time-format t
          ))

(elpaca dired-rainbow
  (use-package dired-rainbow
    :after dired
    :init
    ;; fix for custom ls-lisp time format
    (setopt dired-hacks-datetime-regexp "[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [0-9]\\{2\\}:[0-9]\\{2\\}")
    :config
    ;; * `dired-rainbow-define` - add face by file extension
    ;; * `dired-rainbow-define-chmod` - add face by file permissions
    ;;
    ;; How it works:
    ;; `dired-rainbow-define' and `dired-rainbow-define-chmod' create faces.
    ;; The symbol provided becomes the face name e.g.:
    ;; (dired-rainbow-define markdown ...) => `dired-rainbow-markdown-face'
    ;; Then, the faces can be customised individually.
    (dired-rainbow-define-chmod directory       nil "d.*")
    (dired-rainbow-define-chmod executable-unix nil "-.*x.*")
    (dired-rainbow-define html        nil ("css" "less" "sass" "scss" "htm" "html" "jhtm" "mht" "eml" "mustache" "xhtml"))
    (dired-rainbow-define xml         nil ("xml" "xsd" "xsl" "xslt" "wsdl" "bib" "json" "msg" "pgn" "rss" "yaml" "yml" "rdata"))
    (dired-rainbow-define document    nil ("docm" "doc" "docx" "odb" "odt" "pdb" "pdf" "ps" "rtf" "djvu" "epub" "odp" "ppt" "pptx"))
    (dired-rainbow-define markdown    nil ("org" "etx" "info" "markdown" "md" "mkd" "nfo" "pod" "rst" "tex" "textfile" "txt"))
    (dired-rainbow-define database    nil ("xlsx" "xls" "csv" "accdb" "db" "mdb" "sqlite" "nc"))
    (dired-rainbow-define media       nil ("mp3" "mp4" "MP3" "MP4" "avi" "mpeg" "mpg" "flv" "ogg" "mov" "mid" "midi" "wav" "aiff" "flac"))
    (dired-rainbow-define image       nil ("tiff" "tif" "cdr" "gif" "ico" "jpeg" "jpg" "png" "psd" "eps" "svg" "webp"))
    (dired-rainbow-define log         nil ("log"))
    (dired-rainbow-define shell       nil ("awk" "bash" "bat" "sed" "sh" "zsh" "vim"))
    (dired-rainbow-define interpreted nil ("py" "ipynb" "rb" "pl" "t" "msql" "mysql" "pgsql" "sql" "r" "clj" "cljs" "scala" "js"))
    (dired-rainbow-define compiled    nil ("asm" "cl" "lisp" "el" "elc" "eln" "c" "h" "c++" "h++" "hpp" "hxx" "m" "cc" "cs" "cp" "cpp" "go" "f" "for" "ftn" "f90" "f95" "f03" "f08" "s" "rs" "hi" "hs" "pyc" ".java"))
    (dired-rainbow-define executable  nil ("exe" "msi"))
    (dired-rainbow-define compressed  nil ("7z" "zip" "bz2" "tgz" "txz" "gz" "xz" "z" "Z" "jar" "war" "ear" "rar" "sar" "xpi" "apk" "xz" "tar" "rsn" "vsix"))
    (dired-rainbow-define packaged    nil ("deb" "rpm" "apk" "jad" "jar" "cab" "pak" "pk3" "vdf" "vpk" "bsp"))
    (dired-rainbow-define encrypted   nil ("gpg" "pgp" "asc" "bfe" "enc" "signature" "sig" "p12" "pem"))
    (dired-rainbow-define fonts       nil ("afm" "fon" "fnt" "pfb" "pfm" "ttf" "otf"))
    (dired-rainbow-define partition   nil ("dmg" "iso" "bin" "nrg" "qcow" "toast" "vcd" "vmdk" "bak"))
    (dired-rainbow-define vc          nil ("git" "gitignore" "gitattributes" "gitmodules"))
    ))
(setup dired
  (:require dired-x dired-aux)
  (:hook auto-revert-mode)
  (:put-enable dired-find-alternate-file)

  (setopt
   dired-recursive-copies #'always
   dired-recursive-deletes #'always
   ;; Compress/Archive files
   dired-compress-directory-default-suffix ".tar.zst"
   dired-compress-file-alist '(("\\.zst\\'" . "zstd -qf -11 --rm -o %o %i"))
   dired-compress-files-alist '(("\\.tar\\.zst\\'" . "tar -cf - %i | zstd -11 -o %o"))
   ;; prompt
   dired-deletion-confirmer #'y-or-n-p
   dired-kill-when-opening-new-dired-buffer t ; emacs 28.1 dired-single
   dired-dwim-target t ; [[https://emacs.stackexchange.com/questions/5603/how-to-quickly-copy-move-file-in-emacs-dired/5604#5604][How to quickly copy/move file in Emacs Dired? - Emacs Stack Exchange]]
   dired-hide-details-hide-symlink-targets nil ; always show where symlink points to
   )

  (defun f/dired-find-home ()
    (interactive)
    (dired (getenv "HOME")))

  (:bind "RET" mu-open-in-external-app
         "/" dired-narrow-fuzzy
         "<tab>" dired-subtree-toggle
         "<remap> <dired-maybe-insert-subdir>" dired-subtree-toggle
         "<backtab>" dired-subtree-cycle
         "t" tmtxt/open-current-dir-in-terminal
         "f" dired-find-file
         "b" dired-up-directory

         "h" dired-up-directory        ;; was M-x describe-mode
         "j" dired-next-line           ;; was M-x dired-goto-file
         "k" dired-previous-line       ;; was M-x dired-do-kill-lines
         "l" dired-find-file

         "SPC" dired-mark
         "~" f/dired-find-home
         ))

(setup dired-hide-dotfiles
  (:elpaca dired-hide-dotfiles)
  (keymap-set dired-mode-map "." #'dired-hide-dotfiles-mode) ; was dired-clean-directory
  (setopt dired-hide-dotfiles-verbose nil))

(setup (:elpaca dired-narrow))
(setup (:elpaca dired-subtree))

(setup (:elpaca dired-efap)
  (:with-hook dired-mode-hook
    (:require dired-efap))
  (:with-map dired-mode-map
    (:bind "r" dired-efap))
  (:with-hook dired-efap-mode-hooks
    (setq-local dirvish-hide-cursor nil))
  (setopt dired-efap-initial-filename-selection nil))

(setup (:elpaca all-the-icons-dired)
  (:load-after dired)
  ;; (all-the-icons-install-fonts t) ; on first run to fix missing icons
  (:hook-into dired-mode))

(elpaca diredfl
  (setup direfl
    (diredfl-global-mode)))

(use-package dired-hl-line-mode
  :hook (dired-mode . dired-hl-line-mode))

(provide '11xx-dired)
