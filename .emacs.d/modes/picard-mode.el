;;; picard-mode.el --- MusicBrainz Picard Mode -*- lexical-binding: t; -*-

;;; Commentary:
;; This mode provides support for editing MusicBrainz Picard scripts.

;; NOTE #1: Given Picard Tagger Script's syntax lacks support for indentation.
;; Spaces are always interpreted as such, tabs on the other hand are
;; not interpreted by Picard (and I'd guess it depends on the filesystem
;; allowing filenames with the '\t' character), so only tabs shall be used
;; for indentation when using this mode.
;; `indent-tabs-mode' is locally set to 't' in buffers of this mode.

;; NOTE #2: There is a very limited comment support.
;; Because Emacs uses REGEX for 'font-lock'ing, the full structure of the
;; Picard Tagger scripting language is not supported. So comments
;; should be written in-line or on its own line without having parenthesis
;; inside it e.g. "$noop(tomato sauce)" and not "$noop((tomato) (sauce))".
;; The $noop function works as a "disabler" in Picard, telling it to ignore
;; everything that's inside it, because of that it is also useful for
;; commenting. Unfortunately, I didn't find a solution to properly match
;; parenthesis recursion to hightlight multi-line comments or in-line
;; comments that contain . Without that

;; Copyright (C) 2001  Free Software Foundation, Inc.

;; Author: 11xx
;; Keywords: picard script musicbrainz tagger pts ptsp

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Code:

(defvar picard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [foo] 'picard-do-foo)
    map)
  "Keymap for `picard-mode'.")

(defvar picard-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)
    st)
  "Syntax table for `picard-mode'.")

(defvar picard-mode-font-lock-keywords
  '(("\\$[a-z0-9_-]*" (0 font-lock-function-name-face t))
    ("%[a-zA-Z0-9-_]*%" (0 font-lock-keyword-face t))
    ("\\(\\\\\\\\(\\|\\\\\\\\)\\)" (0 escape-glyph t))
    ("\\$noop([^)]*.)" (0 font-lock-comment-face t))
    "Keyword highlighting specification for `picard-mode'."))

;;;###autoload
(define-derived-mode picard-mode prog-mode "Picard"
  "A major mode for editing Picard Tagger Scripts."
  :syntax-table picard-mode-syntax-table
  (setq-local comment-start "$noop(")
  (setq-local comment-start-skip nil)
  (setq-local comment-end ")")
  (setq-local comment-end-skip nil)
  (setq-local block-comment-start "$noop(")
  (setq-local block-comment-end ")")
  (setq-local font-lock-defaults '(picard-mode-font-lock-keywords)
              font-lock-string-face nil ; this is a "everything is a string" scripting language.
              )
  (setq-local electric-indent-chars (append "()" electric-indent-chars))
  (setq-local indent-tabs-mode t
              tab-width 2))

;;; #TODO-indentation
;;; Indentation
(add-to-list 'auto-mode-alist '("\\(\\.picard\\|\\.pts\\)" . picard-mode))
(provide 'picard-mode)
;;; picard-mode.el ends here
