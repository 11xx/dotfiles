;;; org-bitwarden.el --- Bitwarden secret helper for Org Babel -*- lexical-binding: t; -*-

;; Author: 11xx
;; Version: 20260313
;; Package-Requires: ((emacs "27.1") (org "9.7"))
;; Keywords: org, babel, bitwarden, secrets

;;; Commentary:
;; Registers a `bw' named block in the Org Library of Babel so any org
;; file can retrieve Bitwarden secrets via noweb references:
;;
;;   <<bw(uuid="3e8a1f42-dc4b-4f2a-b7e1-0c9a3d7b2e15")>>
;;   <<bw(uuid="3e8a1f42-dc4b-4f2a-b7e1-0c9a3d7b2e15", field="username")>>
;;
;; Setup — add to init.el:
;;   (require 'org-bitwarden)
;;
;; Selecting a backend:
;;   (setq org-bitwarden-backend 'rbw)   ; default
;;   (setq org-bitwarden-backend 'bw)    ; official Bitwarden CLI
;;
;; Registering a custom backend:
;;   (org-bitwarden-register-backend 'my-backend #'my-getter-fn)
;;   ;; my-getter-fn signature: (uuid-or-name field) -> string
;;
;; Suppress confirmation prompts in an org file by adding at the bottom:
;;   # Local Variables:
;;   # org-confirm-babel-evaluate: nil
;;   # End:

;;; Code:

(require 'ob-lob)


(defgroup org-bitwarden nil
  "Bitwarden secret retrieval for Org Babel."
  :group 'org-babel
  :prefix "org-bitwarden-")


(defvar org-bitwarden--backends '()
  "Alist of (SYMBOL . FUNCTION) backend entries.
Each function must accept (uuid-or-name field) and return a string.
Use `org-bitwarden-register-backend' to add entries.")

(defcustom org-bitwarden-backend 'rbw
  "Backend used to retrieve Bitwarden secrets.

Built-in values:
  `rbw'  — unofficial Rust client with background daemon (recommended)
  `bw'   — official Bitwarden Node.js CLI

Custom backends can be added via `org-bitwarden-register-backend'."
  :type '(symbol)
  :group 'org-bitwarden)

(defun org-bitwarden-register-backend (name fn)
  "Register a Bitwarden retrieval backend.

NAME is a symbol identifying the backend (e.g. \\='my-backend).
FN is a function of two string arguments (UUID-OR-NAME FIELD)
that returns the secret as a string, or signals an error.

Example:
  (org-bitwarden-register-backend
   \\='my-backend
   (lambda (uuid field)
     (my-vault-get uuid field)))

After registering, select it with:
  (setq org-bitwarden-backend \\='my-backend)"
  (unless (symbolp name)
    (error "org-bitwarden: backend name must be a symbol, got %S" name))
  (unless (functionp fn)
    (error "org-bitwarden: backend function must be callable, got %S" fn))
  (setf (alist-get name org-bitwarden--backends) fn))

(defun org-bitwarden--rbw-get (uuid field)
  "Retrieve FIELD from Bitwarden item UUID-OR-NAME using rbw."
  (unless (executable-find "rbw")
    (error "org-bitwarden: `rbw' not found in PATH"))
  (string-trim
   (shell-command-to-string
    (format "rbw get --field %s %s"
            (shell-quote-argument field)
            (shell-quote-argument uuid)))))

(defun org-bitwarden--bw-get (uuid field)
  "Retrieve FIELD from Bitwarden item UUID-OR-NAME using the official bw CLI."
  (unless (executable-find "bw")
    (error "org-bitwarden: `bw' not found in PATH"))
  (unless (getenv "BW_SESSION")
    (error (concat "org-bitwarden: BW_SESSION not set — "
                   "run `bw unlock' and export the session token")))
  ;; bw uses positional subcommands, not --field, for standard fields
  (let* ((subcmd (if (member field '("password" "username" "uri" "notes" "name"))
                     field
                   ;; custom fields require --raw + jq; fall back to a
                   ;; clear error since bw has no --field flag
                   (error (concat "org-bitwarden: `bw' backend does not support "
                                  "custom field %S — use `rbw' instead")
                          field)))
         (val (string-trim
               (shell-command-to-string
                (format "bw get %s %s"
                        (shell-quote-argument subcmd)
                        (shell-quote-argument uuid))))))
    val))

(org-bitwarden-register-backend 'rbw #'org-bitwarden--rbw-get)
(org-bitwarden-register-backend 'bw  #'org-bitwarden--bw-get)

;; retrieval
(defun org-bitwarden-get (uuid field)
  "Retrieve FIELD from Bitwarden item UUID-OR-NAME using `org-bitwarden-backend'.

UUID is a Bitwarden item UUID (preferred) or item name.
FIELD is the field name: \"password\" (default), \"username\",
or any custom field name defined on the item.

Signals an error if the result is empty or the backend fails."
  (let ((fn (alist-get org-bitwarden-backend org-bitwarden--backends)))
    (unless fn
      (error "org-bitwarden: unknown backend `%s' — register it with \
`org-bitwarden-register-backend'" org-bitwarden-backend))
    (let ((val (funcall fn uuid field)))
      (cond
       ((not (stringp val))
        (error "org-bitwarden: backend returned non-string %S" val))
       ((string-empty-p val)
        (error "org-bitwarden: empty result — uuid=%s field=%s" uuid field))
       (t val)))))

;; Library of Babel
(defconst org-bitwarden--lob-source
  "
#+NAME: bw
#+begin_src emacs-lisp :var uuid=\"\" field=\"password\" :tangle no :exports none
(org-bitwarden-get uuid field)
#+end_src
"
  "Org source for the `bw' Library of Babel block.
Calls `org-bitwarden-get' which dispatches to `org-bitwarden-backend'.")

(defun org-bitwarden-lob-ingest ()
  "Idempotently register the `bw' block in the Org Library of Babel."
  (unless (assq 'bw org-babel-library-of-babel)
    (with-temp-buffer
      (insert org-bitwarden--lob-source)
      (org-mode)
      (org-babel-lob-ingest))))

(defun org-bitwarden-unload-function ()
  "Clean up LOB entry when package is unloaded via `unload-feature'."
  (setq org-babel-library-of-babel
        (assq-delete-all 'bw org-babel-library-of-babel))
  nil)

;; Init
(org-bitwarden-lob-ingest)

(provide 'org-bitwarden)
;;; org-bitwarden.el ends here
