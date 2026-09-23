(define-module (aiagent host)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
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
(define %cgroup "/sys/fs/cgroup/aiagent")
(define %delegated "/sys/fs/cgroup/aiagent/delegated")

(define aiagent-home-locked-program
  (program-file
   "aiagent-home"
   #~(begin
       (use-modules (ice-9 popen) (ice-9 rdelim))
       (define (run . command)
         (unless (zero? (apply system* command))
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
                                  #$(file-append coreutils "/bin/stat")
                                  "-f" "-c" "%a %S" "/var/lib/aiagent"))
                (blocks (read port))
                (block-size (read port))
                (status (close-pipe port)))
           (unless (and (zero? (status:exit-val status))
                        (integer? blocks) (>= blocks 0)
                        (integer? block-size) (> block-size 0))
             (error "cannot measure host free space"))
           (* blocks block-size)))
       (directory "/var/lib/aiagent" #o700)
       (let ((mounted-status
              (status:exit-val
               (system* #$(file-append util-linux "/bin/mountpoint")
                        "-q" #$%home))))
         (cond
          ((zero? mounted-status)
           (let* ((port (open-pipe* OPEN_READ
                                    #$(file-append util-linux "/bin/findmnt")
                                    "-n" "-o" "SOURCE" "--mountpoint" #$%home))
                  (source (read-line port))
                  (status (close-pipe port)))
             (unless (and (zero? (status:exit-val status))
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
           (validate-image #$%image))
          ((member mounted-status '(1 32))
           (directory #$%home #o000)
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
                   (run #$(file-append util-linux "/bin/fallocate")
                        "-l" (number->string #$%image-size-bytes) candidate)
                   (chmod candidate #o600)
                   (run #$(file-append e2fsprogs "/sbin/mkfs.ext4")
                        "-F" "-E" "nodiscard" candidate)
                   (validate-image candidate)
                   (let ((status
                          (system* #$(file-append e2fsprogs "/sbin/e2fsck")
                                   "-p" candidate)))
                     (unless (member (status:exit-val status) '(0 1))
                       (error "aiagent candidate failed fsck" status)))
                   (rename-file candidate #$%image))
                 (lambda ()
                   (when (file-exists? candidate)
                     (delete-file candidate))))))
           (validate-image #$%image)
           (let ((status (system* #$(file-append e2fsprogs "/sbin/e2fsck")
                                  "-p" #$%image)))
             (unless (member (status:exit-val status) '(0 1))
               (error "aiagent image failed fsck" status)))
           (run #$(file-append util-linux "/bin/mount")
                "-o" "loop,nodev,nosuid" #$%image #$%home))
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
                                "--exclusive" "/var/lib/aiagent/home.lock"
                                #$aiagent-home-locked-program))
         (error "aiagent home initialization failed")))))

(define aiagent-home-stop-locked-program
  (program-file
   "aiagent-home-stop-locked"
   #~(begin
       (unless (zero? (system* #$(file-append util-linux "/bin/umount")
                                #$%home))
         (error "cannot unmount aiagent home"))
       (chmod #$%home #o000))))

(define aiagent-home-stop-program
  (program-file
   "aiagent-home-stop"
   #~(begin
       (unless (zero? (system* #$(file-append util-linux "/bin/flock")
                                "--exclusive" "/var/lib/aiagent/home.lock"
                                #$aiagent-home-stop-locked-program))
         (error "cannot stop aiagent home")))))

(define aiagent-runtime-program
  (program-file
   "aiagent-runtime"
   #~(begin
       (unless (zero? (system* #$(file-append coreutils "/bin/mkdir")
                                "-p" "/run/aiagent"))
         (error "cannot create aiagent runtime directory"))
       (let ((account (getpwnam "aiagent")))
         (chown "/run/aiagent" (passwd:uid account)
                (passwd:gid account)))
       (chmod "/run/aiagent" #o700))))

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
         (setgroups '())
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
    (one-shot? #t)
    (start #~(lambda _ (zero? (system* #$aiagent-home-program))))
    (stop #~(lambda _
              (if (zero? (system* #$aiagent-home-stop-program))
                  #f
                  (error "cannot stop aiagent home"))))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-runtime))
    (requirement '(user-processes))
    (one-shot? #t)
    (start #~(lambda _ (zero? (system* #$aiagent-runtime-program))))
    (stop #~(const #f))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-cgroup))
    (requirement '(cgroups2-limits))
    (one-shot? #t)
    (start #~(lambda _ (zero? (system* #$aiagent-cgroup-program))))
    (stop #~(const #f))
    (respawn? #f))
   (shepherd-service
    (provision '(aiagent-compose))
    (requirement '(aiagent-home aiagent-runtime aiagent-cgroup
                   networking rootless-podman-shared-root-fs))
    (start #~(make-forkexec-constructor (list #$aiagent-compose-program)))
    (stop #~(make-kill-destructor #:grace-period 1800))
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

(define aiagent-host-service-type
  (service-type
   (name 'aiagent-host)
   (extensions
    (list (service-extension account-service-type aiagent-account)
          (service-extension subids-service-type aiagent-subids)
          (service-extension openssh-service-type aiagent-keys)
          (service-extension pam-root-service-type aiagent-pam-extensions)
          (service-extension shepherd-root-service-type
                             aiagent-shepherd-services)))
   (description "Isolated rootless coding-agent host foundation.")))
