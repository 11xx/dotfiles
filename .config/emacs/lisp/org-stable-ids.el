;;; org-stable-ids.el --- Stable slug-based IDs for Org headings and export  -*- lexical-binding: t; -*-

;; should this be a separate package?
;; Author: The Author <author@example.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1") (org "9.6"))
;; Keywords: org, outlines, export, html
;; URL: https://example.com/org-stable-ids

;;; Commentary:

;; Provides two composable entry points:
;;
;;   `org-stable-id-get-create'  — interactive command that assigns a
;;     human-readable :CUSTOM_ID: to the heading at point, derived from
;;     the heading title.  Collisions are resolved by prepending ancestor
;;     heading slugs (nearest first), then by a numeric suffix.
;;
;;   `org-stable-ids-setup'      — activates an around-advice on
;;     `org-export-get-reference' so that ox-html (and derived backends)
;;     emit stable, slug-based fragment IDs that survive heading renames and
;;     document restructuring.  Pre-existing :CUSTOM_ID: values are honoured
;;     verbatim; <<targets>>, named tables, and list-item targets are also
;;     handled.
;;
;; Example usage:
;;
;;     (with-eval-after-load 'ox
;;       (require 'org-stable-ids)
;;       (org-stable-ids-setup)
;;       (keymap-global-set "C-c o i" #'org-stable-id-get-create))


;;; Code:

(require 'cl-lib)
(require 'rx)
(require 'seq)
(require 'org)
(require 'org-element)


;;;; Customization

;;;###autoload
(defgroup org-stable-ids nil
  "Stable, slug-based identifiers for Org headings and HTML export."
  :group 'org-export
  :prefix "org-stable-ids-"
  :link '(url-link "https://example.com/org-stable-ids"))

;;;###autoload
(defcustom org-stable-ids-separator "-"
  "Token separator used within generated slugs."
  :type 'string
  :group 'org-stable-ids
  :safe #'stringp)

;;;###autoload
(defcustom org-stable-ids-ancestor-separator "--"
  "Separator between an ancestor prefix and the base slug during disambiguation."
  :type 'string
  :group 'org-stable-ids
  :safe #'stringp)

;;;###autoload
(defcustom org-stable-ids-max-slug-length 60
  "Maximum character count for a generated slug; longer slugs are truncated."
  :type 'natnum
  :group 'org-stable-ids
  :safe #'natnump)


;;;; Layer 1 — Slugification (pure)

(defun org-stable-ids--slugify (s)
  "Return a URL-safe, lowercase slug for string S, or nil for blank input.
Whitespace and HTML/shell-unsafe characters become `org-stable-ids-separator'.
Separator runs are collapsed and leading/trailing occurrences are stripped."
  (when (and (stringp s) (string-match-p (rx (not space)) s))
    (let* ((sep    org-stable-ids-separator)
           (sep-re (regexp-quote sep))
           (slug   (downcase s))
           (slug   (replace-regexp-in-string
                    (rx (+ (any " \t\n#<>\"'&()"))) sep slug))
           (slug   (replace-regexp-in-string
                    (concat sep-re "+") sep slug))
           (slug   (string-trim slug
                                (concat sep-re "+")
                                (concat sep-re "+"))))
      (if (> (length slug) org-stable-ids-max-slug-length)
          (substring slug 0 org-stable-ids-max-slug-length)
        slug))))


;;;; Layer 2 — Ancestor traversal (pure)

(defun org-stable-ids--ancestors-from-element (datum)
  "Return ancestor headline raw-values for element DATUM, nearest first.
Relies on `:parent' links being set — available during export tree traversal."
  (let (acc cur)
    (setq cur datum)
    (while (setq cur (org-element-property :parent cur))
      (when (eq (org-element-type cur) 'headline)
        (push (org-element-property :raw-value cur) acc)))
    ;; push while walking root→datum yields farthest-first; reverse it.
    (nreverse acc)))

(defun org-stable-ids--cache-key (datum)
  "Return a path string uniquely identifying headline DATUM within its tree."
  (let ((ancestors (org-stable-ids--ancestors-from-element datum))
        (title     (or (org-element-property :raw-value datum) "")))
    (mapconcat #'identity (append ancestors (list title)) "/")))


;;;; Layer 3 — Disambiguation (stateful against a hash-table)

(defun org-stable-ids--resolve (base-id ancestors used-table
                                        &optional cache-table cache-key)
  "Return a unique variant of BASE-ID not yet recorded in USED-TABLE.

ANCESTORS is a list of heading strings ordered nearest-first (used for
contextual disambiguation before falling back to numeric suffixes).
CACHE-TABLE and CACHE-KEY enable consistent re-resolution so that a TOC
entry and the matching body heading always receive the same fragment ID."
  (cl-block nil
    ;; Cache hit: repeated calls for the same logical heading must agree.
    (when (and cache-table cache-key)
      (when-let* ((hit (gethash cache-key cache-table)))
        (puthash hit t used-table)
        (cl-return hit)))

    (let ((final-id
           (cond
            ;; Base slug is available.
            ((not (gethash base-id used-table))
             base-id)

            ;; Prepend each ancestor slug, nearest first.
            ((cl-loop for anc       in ancestors
                      for prefix    =  (org-stable-ids--slugify anc)
                      for candidate =  (when prefix
                                         (concat prefix
                                                 org-stable-ids-ancestor-separator
                                                 base-id))
                      when (and candidate (not (gethash candidate used-table)))
                      return candidate))

            ;; Numeric suffix fallback.
            (t (cl-loop for n         from 2
                        for candidate =    (format "%s-%d" base-id n)
                        unless (gethash candidate used-table)
                        return candidate)))))

      (puthash final-id t used-table)
      (when (and cache-table cache-key)
        (puthash cache-key final-id cache-table))
      final-id)))


;;;; Layer 4a — Interactive :CUSTOM_ID: assignment

(defun org-stable-ids--buffer-used-table ()
  "Return a hash-table of all :CUSTOM_ID: values in the current buffer."
  (let ((tbl (make-hash-table :test #'equal)))
    (org-map-entries
     (lambda ()
       (when-let* ((id (org-entry-get (point) "CUSTOM_ID")))
         (puthash id t tbl))))
    tbl))

;;;###autoload
(defun org-stable-id-get-create (&optional force)
  "Get or create a slug-based :CUSTOM_ID: for the heading at point.

With a `\\[universal-argument]' prefix (FORCE non-nil), always regenerate
the identifier even if one already exists.

The slug derives from the heading title.  Collisions are resolved by
prepending ancestor slugs (nearest first), then by a numeric suffix.
Does not register entries in `org-id-locations' — `org-store-link'
handles :CUSTOM_ID: links natively without it."
  (interactive "P")
  (unless (org-at-heading-p)
    (user-error "Point is not on an Org heading"))
  (let* ((heading    (nth 4 (org-heading-components)))
         (current-id (org-entry-get nil "CUSTOM_ID")))
    (if (and (not force) (org-string-nw-p current-id))
        (progn (org-store-link nil t) current-id)
      (let* ((base      (or (org-stable-ids--slugify heading)
                            (format "heading-%s"
                                    (substring (md5 (or heading "")) 0 6))))
             ;; `org-get-outline-path' is reliable in live buffers and does
             ;; not require element :parent links to be set.
             (ancestors (nreverse (org-get-outline-path)))
             ;; Exclude the current heading's own ID so force-regeneration
             ;; does not block itself.
             (used-tbl  (let ((tbl (org-stable-ids--buffer-used-table)))
                          (when (org-string-nw-p current-id)
                            (remhash current-id tbl))
                          tbl))
             (new-id    (org-stable-ids--resolve base ancestors used-tbl)))
        (org-entry-put nil "CUSTOM_ID" new-id)
        (org-store-link nil t)
        (message "CUSTOM_ID: %s" new-id)
        new-id))))


;;;; Layer 4b — Export stable-ID advice

(defvar org-stable-ids--used nil
  "Hash-table tracking IDs generated during the current export pass.")

(defvar org-stable-ids--cache nil
  "Hash-table mapping headline cache-keys to resolved IDs for the current export.")

(defun org-stable-ids--export-reset (&rest _)
  "Reset per-export ID tables; called via `org-export-before-processing-functions'."
  (setq org-stable-ids--used  (make-hash-table :test #'equal)
        org-stable-ids--cache (make-hash-table :test #'equal)))

(defun org-stable-ids--first-target (item info)
  "Return the first target or radio-target inside list ITEM, or nil."
  (org-element-map (org-element-contents item) '(target radio-target)
    #'identity info 'first-match))

(defun org-stable-ids--get-reference (orig datum info)
  "Around-advice for `org-export-get-reference' producing stable slug IDs.

Dispatch by element type:
  Headline  → existing :CUSTOM_ID: > slug of heading title
  Target    → slug of target value
  List item → slug of embedded <<target>>, else ORIG
  Table     → slug of #+NAME:, else ORIG
  Other     → ORIG"
  (pcase (org-element-type datum)

    ('headline
     (let* ((custom (org-element-property :CUSTOM_ID datum))
            (base   (or (and (org-string-nw-p custom) custom)
                        (org-stable-ids--slugify
                         (org-element-property :raw-value datum)))))
       (if base
           (org-stable-ids--resolve
            base
            (org-stable-ids--ancestors-from-element datum)
            org-stable-ids--used
            org-stable-ids--cache
            (org-stable-ids--cache-key datum))
         (funcall orig datum info))))

    ((or 'target 'radio-target)
     (let* ((raw   (org-element-property :value datum))
            (clean (and raw (replace-regexp-in-string "[<>]" "" raw)))
            (base  (org-stable-ids--slugify clean)))
       (if base
           (org-stable-ids--resolve
            base
            (org-stable-ids--ancestors-from-element datum)
            org-stable-ids--used)
         (funcall orig datum info))))

    ('item
     (if-let* ((tgt   (org-stable-ids--first-target datum info))
               (raw   (org-element-property :value tgt))
               (clean (replace-regexp-in-string "[<>]" "" raw))
               (base  (org-stable-ids--slugify clean)))
         (org-stable-ids--resolve
          base
          (org-stable-ids--ancestors-from-element datum)
          org-stable-ids--used)
       (funcall orig datum info)))

    ('table
     (if-let* ((name (org-element-property :name datum))
               (base (org-stable-ids--slugify name)))
         (org-stable-ids--resolve
          base
          (org-stable-ids--ancestors-from-element datum)
          org-stable-ids--used)
       (funcall orig datum info)))

    (_ (funcall orig datum info))))


;;;; Setup / teardown

;;;###autoload
(defun org-stable-ids-setup ()
  "Activate the stable-ID export advice and the pre-export reset hook.
Call this inside a `with-eval-after-load' block for \\='ox so that the
`ox' library is guaranteed to be present."
  (require 'ox)
  (add-hook 'org-export-before-processing-functions
            #'org-stable-ids--export-reset)
  (advice-add 'org-export-get-reference
              :around #'org-stable-ids--get-reference
              '((depth . -95))))

;;;###autoload
(defun org-stable-ids-teardown ()
  "Deactivate the stable-ID export advice and hook."
  (remove-hook 'org-export-before-processing-functions
               #'org-stable-ids--export-reset)
  (advice-remove 'org-export-get-reference
                 #'org-stable-ids--get-reference))

(provide 'org-stable-ids)
;;; org-stable-ids.el ends here
