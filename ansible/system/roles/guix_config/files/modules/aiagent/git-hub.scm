(define-module (aiagent git-hub)
  #:use-module (gnu services)
  #:use-module (gnu services version-control)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:export (git-hub-configuration
            git-hub-services))

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
     (rc-file
      (gitolite-rc-file
       (local-code "/etc/git-hub")
       (extra-content
        "    PRE_GIT => ['HubLock::pre_git'],\n    POST_GIT => ['HubLock::post_git'],\n")))
     (git-config
      (gitolite-git-configuration
       (receive-fsck-objects #t)
       (extra-content
        (string-append "[receive]\nmaxInputSize = "
                       (number->string limit) "\n")))))))

(define %hub-lock-activation
  #~(let* ((directory "/var/lib/agentgit-lock")
           (path (string-append directory "/receive.lock"))
           (group (getgrnam "agentgit")))
      (unless group
        (error "Git hub group is unavailable"))
      (unless (file-exists? directory)
        (mkdir directory #o750))
      (let ((metadata (lstat directory)))
        (unless (and (eq? (stat:type metadata) 'directory)
                     (= (stat:uid metadata) 0))
          (error "unsafe Git hub lock directory")))
      (chown directory 0 (group:gid group))
      (chmod directory #o750)
      (let ((fd (open path (logior O_RDWR O_CREAT O_NOFOLLOW O_CLOEXEC) #o660)))
        (let ((metadata (stat fd)))
          (unless (and (eq? (stat:type metadata) 'regular)
                       (= (stat:uid metadata) 0))
            (close fd)
            (error "unsafe Git hub lock file")))
        (close fd))
      (chown path 0 (group:gid group))
      (chmod path #o660)))

(define %hub-hook-program
  (computed-file
   "HubHook.sh"
   #~(begin
       (copy-file #$(local-file "HubHook.sh") #$output)
       (chmod #$output #o555))))

(define (git-hub-services config)
  (list (service gitolite-service-type (git-hub-gitolite config))
        (simple-service
         'git-hub-code etc-service-type
         (cons (list "git-hub/lib/Gitolite/Triggers/HubLock.pm"
                     (local-file "HubLock.pm"))
               (map (lambda (name)
                      (list (string-append "git-hub/hooks/" name)
                            %hub-hook-program))
                    '("pre-receive" "update" "post-receive" "post-update"
                      "proc-receive" "reference-transaction" "push-to-checkout"
                      "pre-auto-gc"))))
        (simple-service
         'git-hub-lock activation-service-type %hub-lock-activation)))
