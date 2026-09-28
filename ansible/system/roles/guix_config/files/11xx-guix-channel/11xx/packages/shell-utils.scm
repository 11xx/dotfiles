;;; Managed by Ansible (role: guix_config) — edit the role, not this file.
;;;
;;; Optional zsh plugins packaged for the local channel.
;;;
;;; Each package installs under share/zsh/plugins/<name>/ so a zsh configuration
;;; can load a consistent entry path.
;;;
;;; Hashes are `guix hash -rx` over a checkout of the tag.

(define-module (11xx packages shell-utils)
  #:use-module (gnu packages shells)
  #:use-module (gnu packages bash)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system copy)
  #:use-module ((guix licenses) #:prefix license:))

(define (zsh-plugin-source name version url hash)
  "Fetch the tag VERSION of the plugin repository at URL."
  (origin
    (method git-fetch)
    (uri (git-reference (url url) (commit version)))
    (file-name (git-file-name name version))
    (sha256 (base32 hash))))

;; Everything under share/zsh/plugins/<name>/, matching Arch's layout.
(define (zsh-plugin-install-plan name)
  `(("." ,(string-append "share/zsh/plugins/" name "/"))))

;; Yoinked from
;; https://gitlab.com/bigbookofbug/bugchan/-/blob/master/bugchan/packages/shell-utils-extra.scm
;; then placed under the powerlevel10k plugin directory.
(define-public zsh-powerlevel10k
  (package
    (name "powerlevel10k")
    (version "v1.20.0")
    (home-page "https://github.com/romkatv/powerlevel10k")
    (source (zsh-plugin-source "powerlevel10k" version
                               "https://github.com/romkatv/powerlevel10k"
                               "1ha7qb601mk97lxvcj9dmbypwx7z5v0b7mkqahzsq073f4jnybhi"))
    (build-system copy-build-system)
    ;; Named explicitly rather than copying ".": the repo carries its own test
    ;; suite and CI config, and the gitstatus subtree alone is most of its size.
    (arguments
     `(#:install-plan
       '(("powerlevel10k.zsh-theme" "share/zsh/plugins/powerlevel10k/")
         ("powerlevel9k.zsh-theme"  "share/zsh/plugins/powerlevel10k/")
         ("config"                  "share/zsh/plugins/powerlevel10k/")
         ("gitstatus"               "share/zsh/plugins/powerlevel10k/")
         ("internal"                "share/zsh/plugins/powerlevel10k/"))))
    (synopsis "Fast reimplementation of the Powerlevel9k zsh theme")
    (description
     "Powerlevel10k is a theme for zsh with an instant prompt and a
gitstatus daemon, so a prompt in a large repository stays responsive.  Source
@file{share/zsh/plugins/powerlevel10k/powerlevel10k.zsh-theme} to use it.")
    (license license:expat)))

(define-public zsh-autopair
  (package
    (name "zsh-autopair")
    (version "v1.0")
    (home-page "https://github.com/hlissner/zsh-autopair")
    (source (zsh-plugin-source "zsh-autopair" version
                               "https://github.com/hlissner/zsh-autopair"
                               "1h0vm2dgrmb8i2pvsgis3lshc5b0ad846836m62y8h3rdb3zmpy1"))
    (build-system copy-build-system)
    (arguments `(#:install-plan ',(zsh-plugin-install-plan "zsh-autopair")))
    (synopsis "Auto-close and delete matching delimiters in zsh")
    (description
     "Inserts the closing member of a pair of brackets or quotes as the opening
one is typed, and removes both when either is deleted.")
    (license license:expat)))

(define-public zsh-autosuggestions
  (package
    (name "zsh-autosuggestions")
    (version "v0.7.1")
    (home-page "https://github.com/zsh-users/zsh-autosuggestions")
    (source (zsh-plugin-source "zsh-autosuggestions" version
                               "https://github.com/zsh-users/zsh-autosuggestions"
                               "02p5wq93i12w41cw6b00hcgmkc8k80aqzcy51qfzi0armxig555y"))
    (build-system copy-build-system)
    (arguments `(#:install-plan ',(zsh-plugin-install-plan "zsh-autosuggestions")))
    (synopsis "Fish-like autosuggestions for zsh")
    (description
     "Suggests the rest of a command from history as it is typed, shown greyed
out ahead of the cursor and accepted with the right arrow key.")
    (license license:expat)))

(define-public zsh-syntax-highlighting
  (package
    (name "zsh-syntax-highlighting")
    (version "0.8.0")
    (home-page "https://github.com/zsh-users/zsh-syntax-highlighting")
    (source (zsh-plugin-source "zsh-syntax-highlighting" version
                               "https://github.com/zsh-users/zsh-syntax-highlighting"
                               "0f482llznpkdg3kv92mjq53djpi4023bdmq06lk1qh05gnp2qg46"))
    (build-system copy-build-system)
    (arguments `(#:install-plan ',(zsh-plugin-install-plan "zsh-syntax-highlighting")))
    (synopsis "Fish-like syntax highlighting for zsh")
    (description
     "Colours the command line as it is typed, so an unknown command or an
unclosed quote is visible before the line is run.")
    (license license:bsd-3)))

(define-public zsh-history-substring-search
  (package
    (name "zsh-history-substring-search")
    (version "v1.1.0")
    (home-page "https://github.com/zsh-users/zsh-history-substring-search")
    (source (zsh-plugin-source "zsh-history-substring-search" version
                               "https://github.com/zsh-users/zsh-history-substring-search"
                               "0vjw4s0h4sams1a1jg9jx92d6hd2swq4z908nbmmm2qnz212y88r"))
    (build-system copy-build-system)
    (arguments
     `(#:install-plan ',(zsh-plugin-install-plan "zsh-history-substring-search")))
    (synopsis "Fish-like history search for zsh")
    (description
     "Searches history for entries containing the text already typed, rather
than only those starting with it.")
    (license license:bsd-3)))
