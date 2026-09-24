(define-module (aiagent git-hub)
  #:use-module (gnu services)
  #:use-module (gnu services version-control)
  #:use-module (guix records)
  #:export (git-hub-configuration
            git-hub-service))

(define-record-type* <git-hub-configuration>
  git-hub-configuration make-git-hub-configuration
  git-hub-configuration?
  (admin-pubkey git-hub-configuration-admin-pubkey)
  (max-push-bytes git-hub-configuration-max-push-bytes
                  (default 33554432)))

(define (git-hub-gitolite config)
  (let ((limit (git-hub-configuration-max-push-bytes config)))
    (unless (and (integer? limit) (> limit 0))
      (error "git hub push limit must be a positive byte count"))
    (gitolite-configuration
     (user "agentgit")
     (group "agentgit")
     (home-directory "/var/lib/agentgit")
     (admin-pubkey (git-hub-configuration-admin-pubkey config))
     (git-config
      (gitolite-git-configuration
       (receive-fsck-objects #t)
       (extra-content
        (string-append "[receive]\nmaxInputSize = "
                       (number->string limit) "\n")))))))

(define (git-hub-service config)
  (service gitolite-service-type (git-hub-gitolite config)))
