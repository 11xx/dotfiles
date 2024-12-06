;; -*- lexical-binding: t; -*-
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'elpaca-bootstrap)

(require '11xx-setup)

(require 'clean-emacs-user-directory)

(setopt native-comp-jit-compilation t
        package-native-compile t
        native-comp-async-report-warnings-errors 'silent)

(setq gc-cons-threshold (* 1000 8 2 100)) ; (* 1000 8) (8KB) is the default
(add-hook 'elpaca-after-init-hook (lambda() (setq gc-cons-percentage 0.6)))

(require '11xx-functions)
(require 'utf-8-default)
(require '11xx-defaults)
(require '11xx-completion)
(require '11xx-ui)
(require '11xx-navigation)
(require '11xx-half-scroll)
(require '11xx-pixel-scroll)
(require '11xx-dired)
(require '11xx-magit)
(require '11xx-org)
(require '11xx-modes)
(require 'llm-ai-assistants)
(require '11xx-pdf-viewer)
