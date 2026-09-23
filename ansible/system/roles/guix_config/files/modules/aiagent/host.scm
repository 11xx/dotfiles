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
(define %cgroup "/sys/fs/cgroup/aiagent")
(define %delegated "/sys/fs/cgroup/aiagent/delegated")

(define aiagent-home-program
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
       (define (validate-image)
         (let ((metadata (stat #$%image)))
           (unless (= (stat:size metadata) (* 256 1024 1024 1024))
             (error "aiagent image has unexpected size"))
           (unless (>= (* 512 (stat:blocks metadata))
                       (* 256 1024 1024 1024))
             (error "aiagent image is not fully allocated"))
           (unless (= (stat:uid metadata) 0)
             (error "aiagent image is not root-owned"))
           (chmod #$%image #o600)))
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
           (validate-image))
          ((member mounted-status '(1 32))
           (directory #$%home #o000)
           (unless (file-exists? #$%image)
             (let ((candidate (string-append #$%image ".new")))
               (when (file-exists? candidate) (delete-file candidate))
               (run #$(file-append util-linux "/bin/fallocate")
                    "-l" "256G" candidate)
               (chmod candidate #o600)
               (run #$(file-append e2fsprogs "/sbin/mkfs.ext4")
                    "-F" "-E" "nodiscard" candidate)
               (rename-file candidate #$%image)))
           (validate-image)
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

(define aiagent-home-stop-program
  (program-file
   "aiagent-home-stop"
   #~(begin
       (unless (zero? (system* #$(file-append util-linux "/bin/umount")
                                #$%home))
         (error "cannot unmount aiagent home"))
       (chmod #$%home #o000))))

(define aiagent-runtime-program
  (program-file
   "aiagent-runtime"
   #~(begin
       (unless (file-exists? "/run/aiagent")
         (mkdir "/run/aiagent" #o700))
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
         (unless (file-exists? path) (mkdir path #o755)))
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
    (start #~(make-forkexec-constructor (list #$aiagent-home-program)))
    (stop #~(lambda _
              (if (zero? (system* #$aiagent-home-stop-program))
                  #f
                  (error "cannot stop aiagent home")))))
   (shepherd-service
    (provision '(aiagent-runtime))
    (requirement '(user-processes))
    (one-shot? #t)
    (start #~(make-forkexec-constructor (list #$aiagent-runtime-program)))
    (stop #~(const #f)))
   (shepherd-service
    (provision '(aiagent-cgroup))
    (requirement '(cgroups2-limits))
    (one-shot? #t)
    (start #~(make-forkexec-constructor (list #$aiagent-cgroup-program)))
    (stop #~(const #f)))
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
