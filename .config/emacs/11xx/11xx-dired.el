(require '11xx-setup)

;; (lambda () (interactive) (find-alternate-file ".."))
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
         (start-process "" nil "launch" file-path))) file-list)))
;; default terminal application path
(defvar v/terminal (getenv "TERMINAL")
  "The default terminal environment vairable.")
;;; function to open new terminal window at current directory
(defun tmtxt/open-current-dir-in-terminal ()
  "Open current directory in 'dired-mode' in terminal application."
  (interactive)
  (shell-command (concat
                  (shell-quote-argument v/terminal)
                  " "
                  "--working-directory"
                  " "
                  (shell-quote-argument (file-truename default-directory)))))

;; (define-key dired-mode-map (kbd "<f4>") 'tmtxt/open-current-dir-in-terminal) ;; was kmacro-end-or-call-macro
(setup dired
  (:load-after dired)
  ;; #TODO-test dired-before-readin-hook
  (:package dired-rainbow
            dired-hide-dotfiles
            dired-narrow
            dired-subtree
            dired-efap
            all-the-icons-dired
            diredfl
            ;; dired-single
            ;; joseph-single-dired
            ;; obsoleted by `dired-kill-when-opening-new-dired-buffer'
            )

  (:also-load dired-x dired-aux)
  (:option dired-listing-switches "-lFAh1v --si --group-directories-first" ;; ls flags
           ls-lisp-dirs-first t ;; show directories on top of the list
           ;; delete-by-moving-to-trash t ;; move to trash instead of hard deleting
           ;; dired-omit-files-p t
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

  (:hook dired-hide-details-mode
         ;; dired-hide-dotfiles-mode
         auto-revert-mode
         diredfl-mode)

  (:also-load dired-rainbow)
  (:with-feature dired-rainbow
    ;; * `dired-rainbow-define` - add face by file extension
    ;; * `dired-rainbow-define-chmod` - add face by file permissions
    (dired-rainbow-define-chmod directory  "#69aaff" "d.*")
    (dired-rainbow-define html             "#f88785" ("css" "less" "sass" "scss" "htm" "html" "jhtm" "mht" "eml" "mustache" "xhtml"))
    (dired-rainbow-define xml              "#b8aa07" ("xml" "xsd" "xsl" "xslt" "wsdl" "bib" "json" "msg" "pgn" "rss" "yaml" "yml" "rdata"))
    (dired-rainbow-define document         "#a89bff" ("docm" "doc" "docx" "odb" "odt" "pdb" "pdf" "ps" "rtf" "djvu" "epub" "odp" "ppt" "pptx"))
    (dired-rainbow-define markdown         "#bda38e" ("org" "etx" "info" "markdown" "md" "mkd" "nfo" "pod" "rst" "tex" "textfile" "txt"))
    (dired-rainbow-define database         "#69aaff" ("xlsx" "xls" "csv" "accdb" "db" "mdb" "sqlite" "nc"))
    (dired-rainbow-define media            "#fd892c" ("mp3" "mp4" "MP3" "MP4" "avi" "mpeg" "mpg" "flv" "ogg" "mov" "mid" "midi" "wav" "aiff" "flac"))
    (dired-rainbow-define image            "#f88785" ("tiff" "tif" "cdr" "gif" "ico" "jpeg" "jpg" "png" "psd" "eps" "svg" "webp"))
    (dired-rainbow-define log              "#d2a022" ("log"))
    (dired-rainbow-define shell            "#fd892c" ("awk" "bash" "bat" "sed" "sh" "zsh" "vim"))
    (dired-rainbow-define interpreted      "#61bd09" ("py" "ipynb" "rb" "pl" "t" "msql" "mysql" "pgsql" "sql" "r" "clj" "cljs" "scala" "js"))
    (dired-rainbow-define compiled         "#00bbb7" ("asm" "cl" "lisp" "el" "elc" "eln" "c" "h" "c++" "h++" "hpp" "hxx" "m" "cc" "cs" "cp" "cpp" "go" "f" "for" "ftn" "f90" "f95" "f03" "f08" "s" "rs" "hi" "hs" "pyc" ".java"))
    (dired-rainbow-define executable       "#61bd09" ("exe" "msi"))
    (dired-rainbow-define compressed       "#61bd09" ("7z" "zip" "bz2" "tgz" "txz" "gz" "xz" "z" "Z" "jar" "war" "ear" "rar" "sar" "xpi" "apk" "xz" "tar" "rsn" "vsix"))
    (dired-rainbow-define packaged         "#fd892c" ("deb" "rpm" "apk" "jad" "jar" "cab" "pak" "pk3" "vdf" "vpk" "bsp"))
    (dired-rainbow-define encrypted        "#b8aa07" ("gpg" "pgp" "asc" "bfe" "enc" "signature" "sig" "p12" "pem"))
    (dired-rainbow-define fonts            "#69aaff" ("afm" "fon" "fnt" "pfb" "pfm" "ttf" "otf"))
    (dired-rainbow-define partition        "#f88785" ("dmg" "iso" "bin" "nrg" "qcow" "toast" "vcd" "vmdk" "bak"))
    (dired-rainbow-define vc               "#69aaff" ("git" "gitignore" "gitattributes" "gitmodules"))
    (dired-rainbow-define-chmod executable-unix "#61bd09" "-.*x.*")
    ;; How it works:
    ;; After defining `dired-rainbow-define'[-chmod], it creates faces with
    ;; the provided SYMBOLs and FACE-PROPS as the default. Then the faces
    ;; can be individually customized on a theme file, overriding the
    ;; default FACE-PROPS. E.g.:
    ;; For (dired-rainbow-define markdown...), the face `dired-rainbow-markdown-face'
    ;; is created.
    )


  ;; Enable disabled commands
  (:put-enable dired-find-alternate-file)

  ;; [remap dired-find-file] dired-single-buffer
  ;; [remap dired-mouse-find-file-other-window] dired-single-buffer-mouse
  ;; [remap dired-up-directory] dired-single-up-directory

  (defun f/dired-find-home ()
    (interactive)
    (dired (getenv "HOME")))
  (:bind "RET" mu-open-in-external-app
         "." dired-hide-dotfiles-mode ;; was dired-clean-directory
         "/" dired-narrow-fuzzy
         "TAB" dired-subtree-toggle
         "S-TAB" dired-subtree-cycle
         "C-c C-t" tmtxt/open-current-dir-in-terminal
         "f" dired-find-file
         "b" dired-up-directory
         ;; vim keys are better at this stuff i guess
         ;; vim keys because we live life on the edge
         "h" dired-up-directory        ;; was M-x describe-mode
         "j" dired-next-line           ;; was M-x dired-goto-file
         "k" dired-previous-line       ;; was M-x dired-do-kill-lines
         "l" dired-find-file
         "SPC" dired-mark
         "~" f/dired-find-home

         ;; ;; dired-single was not working on Emacs 28+ but `joseph-single-dired' is.
         ;; [remap dired-find-file] dired-single-buffer
         ;; [remap dired-mouse-find-file-other-window] dired-single-buffer-mouse
         ;; [remap dired-up-directory] dired-single-up-directory ;; was M-x dired-do-redisplay
         )

  ;; dired-efap
  (:bind "r" dired-efap)
  (:with-feature dired-efap
    (:option dired-efap-initial-filename-selection nil))

  (:with-feature all-the-icons-dired
    (:load-after dired)
    (:hook-into dired-mode))

  ;; (eval-after-load 'dired '(progn (require 'joseph-single-dired)))
  ;; (:with-feature joseph-single-dired
  ;;   (:load-after dired))

  ;; show current directory in the header
  (defun f/dired-dir-header-line ()
    "Uses `header-line-format' to display the current directory."
    (interactive)
    (setq-local header-line-format
                '((:eval (abbreviate-file-name default-directory)))))
  ;; my/dired-dir-header-line

  (add-hook 'dired-mode-hook 'f/dired-dir-header-line)
  ) ; "(setup dired..." ends here

;; customize faces with =dired-subtree-depth-[1-6]-face=

(provide '11xx-dired)
