;;; Managed by Ansible (role: guix_config) — edit the role, not this file.
;;;
;;; Network packages whose release cadence cannot wait for another channel.

(define-module (11xx packages networking)
  #:use-module (guix base32)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module ((rosenthal packages networking) #:prefix rosenthal:))

;; Rosenthal supplies the Guix-specific build and SSH PATH patches, but its
;; package can lag security releases. Keep those integration details while
;; pinning the source and vendored Go dependencies independently.
(define-public tailscale
  (package
    (inherit rosenthal:tailscale)
    (version "1.102.2")
    (source
     (origin
       (inherit (package-source rosenthal:tailscale))
       (uri (git-reference
             (url "https://github.com/tailscale/tailscale")
             (commit (string-append "v" version))))
       (file-name (git-file-name "tailscale" version))
       (sha256
        (base32
         "1227ck9gdds0kaf0dpcjzq8cz1bfjnj72hk2y7z39qhiy63558xy"))))
    (arguments
     (substitute-keyword-arguments
         (package-arguments rosenthal:tailscale)
       ((#:vendor-hash _)
        (base32
         "01wvidvld4749f9bdsmvi84l005k6lfsqvcn6yw13jikzd8a8qka"))))))
