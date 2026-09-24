(define-module (aiagent host)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python)
  #:use-module (gnu services)
  #:use-module (gnu services mcron)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services ssh)
  #:use-module (gnu system accounts)
  #:use-module (gnu system pam)
  #:use-module (gnu system shadow)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:export (aiagent-host-service-type))

(define %image "/var/lib/aiagent/home.ext4")
(define %home "/home/aiagent")
(define %image-size-bytes (* 256 1024 1024 1024))
(define %host-free-reserve-bytes (* 128 1024 1024 1024))
(define %home-lock-wait-seconds 300)
(define %home-probe-seconds 30)
(define %home-allocation-seconds 600)
(define %home-format-seconds 300)
(define %home-fsck-seconds 1200)
(define %home-mount-seconds 120)
(define %home-unmount-seconds 120)
(define %cgroup-drain-seconds 60)
(define %cgroup-drain-poll-seconds 1)
(define %podman-stop-grace-seconds 10)
(define %podman-stop-deadline-seconds 180)
(define %podman-reconcile-seconds 60)
(define %runtime-init-seconds 60)
(define %cgroup-init-seconds 60)
(define %cgroup "/sys/fs/cgroup/aiagent")
(define %delegated "/sys/fs/cgroup/aiagent/delegated")

(define aiagent-home-locked-program
  (program-file
   "aiagent-home"
   #~(begin
       (use-modules (ice-9 popen) (ice-9 rdelim))
       (define (timed-status seconds . command)
         (let* ((status (apply system* #$(file-append coreutils "/bin/timeout")
                               "--signal=KILL" (number->string seconds)
                               command))
                (exit (status:exit-val status)))
           (if (number? exit) exit 137)))
       (define (run seconds . command)
         (unless (zero? (apply timed-status seconds command))
           (error "aiagent home command failed" command)))
       (define (directory path mode)
         (unless (file-exists? path) (mkdir path mode))
         (chmod path mode))
       (define (validate-image path)
         (let ((metadata (stat path)))
           (unless (= (stat:size metadata) #$%image-size-bytes)
             (error "aiagent image has unexpected size"))
           (unless (>= (* 512 (stat:blocks metadata))
                       #$%image-size-bytes)
             (error "aiagent image is not fully allocated"))
           (unless (= (stat:uid metadata) 0)
             (error "aiagent image is not root-owned"))
           (chmod path #o600)))
       (define (available-host-bytes)
         (let* ((port (open-pipe* OPEN_READ
                                  #$(file-append coreutils "/bin/timeout")
                                  "--signal=KILL"
                                  #$(number->string %home-probe-seconds)
                                  #$(file-append coreutils "/bin/stat")
                                  "-f" "-c" "%a %S" "/var/lib/aiagent"))
                (blocks (read port))
                (block-size (read port))
                (status (close-pipe port)))
           (unless (and (equal? (status:exit-val status) 0)
                        (integer? blocks) (>= blocks 0)
                        (integer? block-size) (> block-size 0))
             (error "cannot measure host free space"))
           (* blocks block-size)))
       (define (reserve-existing-image)
         (let* ((metadata (stat #$%image))
                (allocated (* 512 (stat:blocks metadata)))
                (missing (max 0 (- #$%image-size-bytes allocated))))
           (unless (= (stat:size metadata) #$%image-size-bytes)
             (error "aiagent image has unexpected size"))
           (unless (= (stat:uid metadata) 0)
             (error "aiagent image is not root-owned"))
           (when (> missing 0)
             (unless (>= (available-host-bytes)
                         (+ missing #$%host-free-reserve-bytes))
               (error "insufficient host free space to restore aiagent image allocation"))
             (run #$%home-allocation-seconds
                  #$(file-append util-linux "/bin/fallocate")
                  "-l" (number->string #$%image-size-bytes) #$%image))))
       (directory "/var/lib/aiagent" #o700)
       (let ((mounted-status
              (timed-status #$%home-probe-seconds
                            #$(file-append util-linux "/bin/mountpoint")
                            "-q" #$%home)))
         (cond
          ((zero? mounted-status)
           (let* ((port (open-pipe* OPEN_READ
                                    #$(file-append coreutils "/bin/timeout")
                                    "--signal=KILL"
                                    #$(number->string %home-probe-seconds)
                                    #$(file-append util-linux "/bin/findmnt")
                                    "-n" "-o" "SOURCE" "--mountpoint" #$%home))
                  (source (read-line port))
                  (status (close-pipe port)))
             (unless (and (equal? (status:exit-val status) 0)
                          (string? source)
                          (> (string-length source) 9)
                          (string=? (substring source 0 9) "/dev/loop")
                          (string=?
                           (call-with-input-file
                               (string-append "/sys/block/"
                                              (substring source 5)
                                              "/loop/backing_file")
                             read-line)
                           #$%image))
               (error "aiagent home is mounted from another source")))
           (reserve-existing-image)
           (validate-image #$%image))
          ((member mounted-status '(1 32))
           (directory #$%home #o000)
           (let ((created? #f))
             (unless (file-exists? #$%image)
               (let ((candidate (string-append #$%image ".new")))
                 (when (file-exists? candidate) (delete-file candidate))
                 (unless (>= (available-host-bytes)
                             (+ #$%image-size-bytes
                                #$%host-free-reserve-bytes))
                   (error "insufficient host free space for aiagent image and reserve"))
                 (dynamic-wind
                   (lambda () #t)
                   (lambda ()
                     (run #$%home-allocation-seconds
                          #$(file-append util-linux "/bin/fallocate")
                          "-l" (number->string #$%image-size-bytes) candidate)
                     (chmod candidate #o600)
                     (run #$%home-format-seconds
                          #$(file-append e2fsprogs "/sbin/mkfs.ext4")
                          "-F" "-E"
                          "nodiscard,lazy_itable_init=0,lazy_journal_init=0"
                          candidate)
                     (validate-image candidate)
                     (let ((status
                            (timed-status #$%home-fsck-seconds
                                          #$(file-append e2fsprogs "/sbin/e2fsck")
                                          "-p" candidate)))
                       (unless (member status '(0 1))
                         (error "aiagent candidate failed fsck" status)))
                     (rename-file candidate #$%image))
                   (lambda ()
                     (when (file-exists? candidate)
                       (delete-file candidate)))))
               (set! created? #t))
             (unless created?
               (reserve-existing-image))
             (validate-image #$%image)
             (unless created?
               (let ((status (timed-status #$%home-fsck-seconds
                                           #$(file-append e2fsprogs "/sbin/e2fsck")
                                           "-p" #$%image)))
                 (unless (member status '(0 1))
                   (error "aiagent image failed fsck" status))))
             (run #$%home-mount-seconds
                  #$(file-append util-linux "/bin/mount")
                  "-o" "loop,nodev,nosuid" #$%image #$%home)))
          (else (error "cannot inspect aiagent home mount")))
         (let ((account (getpwnam "aiagent")))
           (chown #$%home (passwd:uid account) (passwd:gid account)))
         (chmod #$%home #o700)))))

(define aiagent-home-program
  (program-file
   "aiagent-home"
   #~(begin
       (unless (zero? (system* #$(file-append coreutils "/bin/mkdir")
                                "-p" "/var/lib/aiagent"))
         (error "cannot create aiagent state directory"))
       (chmod "/var/lib/aiagent" #o700)
       (let ((port (open-file "/var/lib/aiagent/home.lock" "a")))
         (chmod "/var/lib/aiagent/home.lock" #o600)
         (close-port port))
       (unless (zero? (system* #$(file-append util-linux "/bin/flock")
                                "--exclusive" "-w"
                                #$(number->string %home-lock-wait-seconds)
                                "/var/lib/aiagent/home.lock"
                                #$aiagent-home-locked-program))
         (error "aiagent home initialization failed")))))

(define aiagent-podman-stop-program
  (program-file
   "aiagent-podman-stop"
   #~(begin
       (let ((account (getpwnam "aiagent")))
         (call-with-output-file
             (string-append #$%delegated "/service/cgroup.procs")
           (lambda (port) (display (getpid) port)))
         (setgroups #())
         (setgid (passwd:gid account))
         (setuid (passwd:uid account))
         (setenv "HOME" #$%home)
         (setenv "XDG_RUNTIME_DIR" "/run/aiagent")
         (setenv "TMPDIR" "/home/aiagent/tmp")
         (setenv "CONTAINERS_IMAGE_COPY_TMPDIR"
                 "/home/aiagent/image-copy-tmp")
         (setenv "PATH"
                 "/run/privileged/bin:/home/aiagent/.guix-profile/bin:/run/current-system/profile/bin:/usr/bin:/bin")
         (execl "/run/current-system/profile/bin/podman" "podman"
                "stop" "--all" "--time"
                #$(number->string %podman-stop-grace-seconds))))))

(define aiagent-cgroup-drain-program
  (program-file
   "aiagent-cgroup-drain"
   #~(begin
       (use-modules (ice-9 ftw))
       (define target
         (cond ((equal? (cdr (command-line)) '("all")) #$%delegated)
               ((equal? (cdr (command-line)) '("service"))
                (string-append #$%delegated "/service"))
               (else (error "invalid aiagent cgroup drain target"))))
       (define (uptime-seconds)
         (call-with-input-file "/proc/uptime" read))
       (define (populated? directory)
         (call-with-input-file (string-append directory "/cgroup.events")
           (lambda (port)
             (let loop ((name (read port)))
               (when (eof-object? name)
                 (error "aiagent cgroup.events has no populated field"))
               (let ((value (read port)))
                 (if (eq? name 'populated)
                     (case value
                       ((0) #f)
                       ((1) #t)
                       (else (error "invalid aiagent cgroup populated value" value)))
                     (loop (read port))))))))
       (define (remaining-pids directory)
         (catch 'system-error
           (lambda ()
             (append
              (call-with-input-file
                  (string-append directory "/cgroup.procs")
                (lambda (port)
                  (let loop ((pid (read port)))
                    (if (eof-object? pid) '()
                        (cons pid (loop (read port)))))))
              (apply append
                     (map (lambda (name)
                            (let ((child (string-append directory "/" name)))
                              (catch 'system-error
                                (lambda ()
                                  (if (eq? (stat:type (stat child)) 'directory)
                                      (remaining-pids child)
                                      '()))
                                (lambda _ '()))))
                          (scandir directory
                                   (lambda (name)
                                     (not (member name '("." "..")))))))))
           (lambda _ '())))
       (define (remove-empty-descendants directory)
         (for-each
          (lambda (name)
            (let ((child (string-append directory "/" name)))
              (when (catch 'system-error
                      (lambda () (eq? (stat:type (stat child)) 'directory))
                      (lambda _ #f))
                (remove-empty-descendants child)
                (unless (or (string=? child
                                     (string-append #$%delegated "/service"))
                            (populated? child))
                  (rmdir child)))))
          (scandir directory
                   (lambda (name) (not (member name '("." "..")))))))
       (unless (= (geteuid) 0)
         (error "aiagent cgroup drain requires root"))
       (call-with-output-file (string-append target "/cgroup.kill")
         (lambda (port) (display "1" port)))
       (let ((deadline (+ (uptime-seconds) #$%cgroup-drain-seconds)))
         (let loop ()
           (when (populated? target)
             (if (>= (uptime-seconds) deadline)
                 (error "aiagent cgroup remains populated; remaining PIDs"
                        (remaining-pids target))
                 (begin
                   (sleep #$%cgroup-drain-poll-seconds)
                   (loop)))))
       (remove-empty-descendants target)
       (when (populated? target)
         (error "aiagent cgroup repopulated during cleanup; remaining PIDs"
                (remaining-pids target)))))))

(define aiagent-home-stop-locked-program
  (program-file
   "aiagent-home-stop-locked"
   #~(begin
       (unless (zero? (system* #$(file-append coreutils "/bin/timeout")
                                "--signal=KILL"
                                #$(number->string %podman-stop-deadline-seconds)
                                #$aiagent-podman-stop-program))
         (display "aiagent Podman stop incomplete; forcing cgroup drain\n"
                  (current-error-port)))
       (unless (zero? (system* #$aiagent-cgroup-drain-program "all"))
         (error "aiagent delegated cgroup did not drain"))
       (unless (zero? (system* #$(file-append coreutils "/bin/timeout")
                                "--signal=KILL"
                                #$(number->string %home-unmount-seconds)
                                #$(file-append util-linux "/bin/umount")
                                #$%home))
         (error "aiagent home may remain mounted; check findmnt"))
       (chmod #$%home #o000))))

(define aiagent-home-stop-program
  (program-file
   "aiagent-home-stop"
   #~(begin
       (unless (zero? (system* #$(file-append util-linux "/bin/flock")
                                "--exclusive" "-w"
                                #$(number->string %home-lock-wait-seconds)
                                "/var/lib/aiagent/home.lock"
                                #$aiagent-home-stop-locked-program))
         (error "aiagent home stop failed; check findmnt")))))

(define aiagent-runtime-program
  (program-file
   "aiagent-runtime"
   #~(begin
       (unless (zero? (system* #$(file-append coreutils "/bin/mkdir")
                                "-p" "/run/aiagent"))
         (error "cannot create aiagent runtime directory"))
       (let ((account (getpwnam "aiagent")))
         (chown "/run/aiagent" (passwd:uid account)
                (passwd:gid account))
         (chmod "/run/aiagent" #o700)
         (let ((fd (open "/run/aiagent/aiagent.lock"
                         (logior O_WRONLY O_CREAT O_NOFOLLOW O_NONBLOCK)
                         #o600)))
           (unless (eq? (stat:type (fstat fd)) 'regular)
             (error "aiagent operation lock is not a regular file"))
           (chown fd (passwd:uid account) (passwd:gid account))
           (chmod fd #o600)
           (close fd))))))

(define aiagent-cgroup-program
  (program-file
   "aiagent-cgroup"
   #~(begin
       (define (write path value)
         (call-with-output-file path (lambda (port) (display value port))))
       (define (ensure path)
         (unless (zero? (system* #$(file-append coreutils "/bin/mkdir")
                                  "-p" path))
           (error "cannot create aiagent cgroup" path)))
       (ensure #$%cgroup)
       (write (string-append #$%cgroup "/cpu.max") "400000 100000")
       (write (string-append #$%cgroup "/cpu.weight") "50")
       (write (string-append #$%cgroup "/memory.max")
              (number->string (* 12 1024 1024 1024)))
       (write (string-append #$%cgroup "/memory.high")
              (number->string (* 10 1024 1024 1024)))
       (write (string-append #$%cgroup "/pids.max") "4096")
       (write (string-append #$%cgroup "/cgroup.subtree_control")
              "+cpu +memory +pids")
       (ensure #$%delegated)
       (write (string-append #$%delegated "/cgroup.subtree_control")
              "+cpu +memory +pids")
       (let* ((account (getpwnam "aiagent"))
              (uid (passwd:uid account))
              (gid (passwd:gid account)))
         (chown #$%delegated uid gid)
         (for-each (lambda (name)
                     (chown (string-append #$%delegated "/" name)
                            uid gid))
                   '("cgroup.procs" "cgroup.threads"
                     "cgroup.subtree_control"))
         (ensure (string-append #$%delegated "/service"))
         (chown (string-append #$%delegated "/service") uid gid)
         (chown (string-append #$%delegated "/service/cgroup.procs")
                uid gid)))))

(define aiagent-ssh-placement-program
  (program-file
   "aiagent-ssh-placement"
   #~(begin
       (when (and (string=? (or (getenv "PAM_USER") "") "aiagent")
                  (string=? (or (getenv "PAM_TYPE") "") "open_session"))
         (unless (file-exists? #$%delegated)
           (error "aiagent cgroup is unavailable"))
         (unless (= (geteuid) 0)
           (error "aiagent SSH placement requires root"))
         (let* ((pid (getppid))
                (leaf (string-append #$%delegated "/ssh-"
                                     (number->string pid)))
                (account (getpwnam "aiagent")))
           (unless (file-exists? leaf) (mkdir leaf #o700))
           (chown leaf (passwd:uid account) (passwd:gid account))
           (chown (string-append leaf "/cgroup.procs")
                  (passwd:uid account) (passwd:gid account))
           (call-with-output-file (string-append leaf "/cgroup.procs")
             (lambda (port) (display pid port))))))))

(define aiagent-compose-program
  (program-file
   "aiagent-compose"
   #~(begin
       (let* ((account (getpwnam "aiagent"))
              (uid (passwd:uid account))
              (gid (passwd:gid account)))
         (call-with-output-file
             (string-append #$%delegated "/service/cgroup.procs")
           (lambda (port) (display (getpid) port)))
         (setgroups #())
         (setgid gid)
         (setuid uid)
         (chdir #$%home)
         (setenv "HOME" #$%home)
         (setenv "XDG_RUNTIME_DIR" "/run/aiagent")
         (setenv "GAK_COMPOSE_SERVICES_ROOT" "/home/aiagent/services")
         (setenv "GAK_COMPOSE_RUNTIME_DIR" "/run/aiagent/gak-compose")
         (setenv "TMPDIR" "/home/aiagent/tmp")
         (setenv "CONTAINERS_IMAGE_COPY_TMPDIR" "/home/aiagent/image-copy-tmp")
         (setenv "PODMAN_COMPOSE_PROVIDER"
                 "/home/aiagent/.guix-profile/bin/podman-compose")
         (setenv "PATH"
                 "/run/privileged/bin:/home/aiagent/.guix-profile/bin:/run/current-system/profile/bin:/usr/bin:/bin")
         (unless (zero? (system* #$(file-append coreutils "/bin/timeout")
                                  "--signal=KILL"
                                  #$(number->string %podman-reconcile-seconds)
                                  "/home/aiagent/.local/bin/gak-aiagent-reconcile"))
           (error "aiagent Podman state reconciliation failed"))
         (execl "/home/aiagent/.local/bin/gak-compose-lifecycle"
                "gak-compose-lifecycle" "run")))))

(define aiagent-shell-program
  (program-file
   "aiagent-shell"
   #~(begin
       (setenv "HOME" #$%home)
       (setenv "XDG_RUNTIME_DIR" "/run/aiagent")
       (setenv "TMPDIR" "/home/aiagent/tmp")
       (setenv "CONTAINERS_IMAGE_COPY_TMPDIR" "/home/aiagent/image-copy-tmp")
       (setenv "PODMAN_COMPOSE_PROVIDER"
               "/home/aiagent/.guix-profile/bin/podman-compose")
       (setenv "PATH"
               "/run/privileged/bin:/home/aiagent/.guix-profile/bin:/run/current-system/profile/bin:/usr/bin:/bin")
       (if (null? (cdr (command-line)))
           (execl #$(file-append bash "/bin/bash") "bash" "-l")
           (apply execl #$(file-append bash "/bin/bash") "bash"
                  (cdr (command-line)))))))

(define (aiagent-shepherd-services _)
  (list
   (shepherd-service
   (provision '(aiagent-home))
    (requirement '(user-processes))
    (start #~(lambda _ (zero? (system* #$aiagent-home-program))))
    (stop #~(lambda _
              (define (remaining-pids directory)
                (catch 'system-error
                  (lambda ()
                    (append
                     (call-with-input-file
                         (string-append directory "/cgroup.procs")
                       (lambda (port)
                         (let loop ((pid (read port)))
                           (if (eof-object? pid) '()
                               (cons pid (loop (read port)))))))
                     (apply append
                            (map (lambda (name)
                                   (let ((child (string-append directory "/" name)))
                                     (catch 'system-error
                                       (lambda ()
                                         (if (eq? (stat:type (stat child))
                                                  'directory)
                                             (remaining-pids child)
                                             '()))
                                       (lambda _ '()))))
                                 ((@ (ice-9 ftw) scandir) directory
                                  (lambda (name)
                                    (not (member name '("." "..")))))))))
                  (lambda _ '())))
              (if (zero? (system* #$aiagent-home-stop-program))
                  #f
                  (error "aiagent home may remain mounted; check findmnt; remaining delegated PIDs"
                         (remaining-pids #$%delegated)))))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-runtime))
    (requirement '(user-processes))
    (one-shot? #t)
    (start #~(lambda _
               (zero? (system* #$(file-append coreutils "/bin/timeout")
                               "--signal=KILL"
                               #$(number->string %runtime-init-seconds)
                               #$aiagent-runtime-program))))
    (stop #~(const #f))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-cgroup))
    (requirement '(cgroups2-limits))
    (one-shot? #t)
    (start #~(lambda _
               (zero? (system* #$(file-append coreutils "/bin/timeout")
                               "--signal=KILL"
                               #$(number->string %cgroup-init-seconds)
                               #$aiagent-cgroup-program))))
    (stop #~(const #f))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-compose))
    (requirement '(aiagent-home aiagent-runtime aiagent-cgroup
                   networking rootless-podman-shared-root-fs))
    (start #~(make-forkexec-constructor (list #$aiagent-compose-program)))
    (stop #~(lambda (process)
              ((make-kill-destructor #:grace-period 1800) process)
              (unless (zero? (system* #$aiagent-cgroup-drain-program "service"))
                (error "aiagent Compose cgroup did not drain"))
              #f))
    (respawn? #f))))

(define (aiagent-pam-extensions _)
  (list
   (pam-extension
    (transformer
     (lambda (pam)
       (if (string=? (pam-service-name pam) "sshd")
           (pam-service
            (inherit pam)
            (session
             (append (pam-service-session pam)
                     (list (pam-entry
                            (control "required")
                            (module "pam_exec.so")
                            (arguments
                             (list "type=open_session" "seteuid"
                                   #~#$aiagent-ssh-placement-program)))))))
           pam))))))

(define (aiagent-account _)
  (list (user-group (name "aiagent") (system? #t))
        (user-account
         (name "aiagent")
         (group "aiagent")
         (supplementary-groups '())
         (home-directory %home)
         (create-home-directory? #f)
         (shell aiagent-shell-program))))

(define (aiagent-subids _)
  (subids-extension
   (subuids (list (subid-range (name "aiagent")
                                (start 231072) (count 65536))))
   (subgids (list (subid-range (name "aiagent")
                                (start 231072) (count 65536))))))

(define (aiagent-keys keys)
  (list (cons "aiagent" keys)))

(define %backup-script (local-file "backup.py"))

(define (aiagent-backup-jobs _)
  (list
   #~(job "* * * * *"
          (string-append #$(file-append python "/bin/python3")
                         " " #$%backup-script " request")
          #:user "root")
   #~(job "15 4 * * *"
          (string-append #$(file-append python "/bin/python3")
                         " " #$%backup-script " daily")
          #:user "root")))

(define aiagent-host-service-type
  (service-type
   (name 'aiagent-host)
   (extensions
    (list (service-extension account-service-type aiagent-account)
          (service-extension subids-service-type aiagent-subids)
          (service-extension openssh-service-type aiagent-keys)
          (service-extension pam-root-service-type aiagent-pam-extensions)
          (service-extension mcron-service-type aiagent-backup-jobs)
          (service-extension shepherd-root-service-type
                             aiagent-shepherd-services)))
   (description "Isolated rootless coding-agent host foundation.")))
