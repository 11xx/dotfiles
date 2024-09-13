(require '11xx-setup)

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "var/eln-cache/" user-emacs-directory))))

(add-to-list 'native-comp-eln-load-path
             (convert-standard-filename
              (expand-file-name "var/eln-cache/" user-emacs-directory)))

(setup (:elpaca no-littering)
  (:require no-littering))

(provide 'init-no-littering)
