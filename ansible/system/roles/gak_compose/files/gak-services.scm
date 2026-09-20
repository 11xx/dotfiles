(use-modules (guix packages)
             (guix gexp)
             (guix utils)
             (guix build-system trivial)
             (gnu packages bash)
             (gnu packages python)
             (gnu packages python-xyz))

(package
  (name "gak-services")
  (version "1.0")
  (source (local-file "gak-services.py"))
  (build-system trivial-build-system)
  (arguments
   (list
    #:modules '((guix build utils))
    #:builder
    #~(begin
        (use-modules (guix build utils))
        (let* ((bin (string-append #$output "/bin"))
               (lib (string-append #$output "/libexec"))
               (command (string-append bin "/gak-services"))
               (implementation (string-append lib "/gak-services.py")))
          (mkdir-p bin)
          (mkdir-p lib)
          (copy-file #$(package-source this-package) implementation)
          (call-with-output-file command
            (lambda (port)
              (format port "#!~a/bin/sh~%unset PYTHONPATH PYTHONHOME PYTHONSTARTUP~%export GUIX_PYTHONPATH='~a/lib/python~a/site-packages'~%exec '~a/bin/python3' -I '~a' \"$@\"~%"
                      #$bash-minimal #$python-pyyaml
                      #$(version-major+minor (package-version python))
                      #$python implementation)))
          (chmod command #o555)
          (invoke command "--help")))))
  (home-page "https://guix.gnu.org/")
  (synopsis "Rootless Compose project updates")
  (description "Discover user-owned Compose projects and update running applications with backup and readiness gates.")
  (license #f))
