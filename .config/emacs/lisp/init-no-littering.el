;; -*- lexical-binding: t; -*-
(elpaca no-littering (require 'no-littering))
(elpaca-wait)

(when (fboundp 'startup-redirect-eln-cache)
  (startup-redirect-eln-cache
   (convert-standard-filename
    (expand-file-name  "eln-cache" no-littering-var-directory))))

(add-to-list 'native-comp-eln-load-path
             (convert-standard-filename
              (expand-file-name "eln-cache" no-littering-var-directory)))

(provide 'init-no-littering)
