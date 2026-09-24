#!/usr/bin/env python3
"""Exercise built aiagent programs in a rootless user namespace on gak."""

import json
import hashlib
import os
from pathlib import Path
import pwd
import re
import subprocess
import sys
import tempfile


PROFILE = Path("/run/current-system/profile/bin")
SBIN = Path("/run/current-system/profile/sbin")


def command(*args, check=True, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr[-400:]}")
    return result


def namespace(*args, **kwargs):
    return command("podman", "unshare", *map(str, args), **kwargs)


def built(module_dir, name):
    expression = f"(@@ (aiagent host) {name})"
    result = command(
        "guix", "build", "-L", str(module_dir), "-e", expression,
        env={**os.environ, "GUILE_AUTO_COMPILE": "0"},
    )
    return Path(result.stdout.strip().splitlines()[-1])


def script(path, source):
    path.write_text(source)
    path.chmod(0o755)
    return path


def namespace_owner(path):
    value = namespace(PROFILE / "stat", "-c", "%u %g %a", path).stdout.strip()
    uid, gid, mode = map(int, value.split())
    return uid, gid, mode


def probe_runtime_cgroup_pam(module_dir, root, account):
    runtime = root / "runtime"
    runtime_source = built(module_dir, "aiagent-runtime-program").read_text()
    runtime_program = script(root / "runtime.scm", runtime_source.replace("/run/aiagent", str(runtime)))
    namespace(runtime_program)
    assert namespace_owner(runtime) == (account.pw_uid, account.pw_gid, 700)
    print("runtime: mkdir/chown/chmod passed")

    cgroup = root / "cgroup"
    delegated = cgroup / "delegated"
    service = delegated / "service"
    service.mkdir(parents=True)
    for item in (
        delegated / "cgroup.procs", delegated / "cgroup.threads",
        delegated / "cgroup.subtree_control", service / "cgroup.procs",
    ):
        item.write_text("")
    cgroup_source = built(module_dir, "aiagent-cgroup-program").read_text()
    cgroup_program = script(root / "cgroup.scm", cgroup_source.replace("/sys/fs/cgroup/aiagent", str(cgroup)))
    namespace(cgroup_program)
    assert namespace_owner(delegated)[:2] == (account.pw_uid, account.pw_gid)
    assert (cgroup / "cpu.max").read_text() == "400000 100000"
    assert (cgroup / "memory.max").read_text() == str(12 * 1024**3)
    print("cgroup: ordinary-file writes and chown passed; kernel delegation untested")

    pam_root = root / "pam-delegated"
    pam_root.mkdir()
    pam_source = built(module_dir, "aiagent-ssh-placement-program").read_text()
    header, body = pam_source.split("!#\n", 1)
    body = body.replace("/sys/fs/cgroup/aiagent/delegated", str(pam_root))
    mkdir_harness = '''(define actual-mkdir mkdir)
(let ((mkdir (lambda (path mode)
  (let ((result (actual-mkdir path mode)))
    (call-with-output-file (string-append path "/cgroup.procs")
      (lambda (port) #t))
    result)))) BODY)
'''.replace("BODY", body)
    pam_program = script(root / "pam.scm", header + "!#\n" + mkdir_harness)
    for user in ("lobo", "root"):
        namespace(PROFILE / "env", f"PAM_USER={user}", "PAM_TYPE=open_session", pam_program)
    wrapper = root / "pam-wrapper.py"
    wrapper.write_text(
        "import os, pathlib, subprocess, sys\n"
        "program=pathlib.Path(sys.argv[1]); parent=pathlib.Path(sys.argv[2])\n"
        "pid=os.getpid(); leaf=parent/f'ssh-{pid}'; assert not leaf.exists()\n"
        "env={**os.environ, 'PAM_USER':'aiagent', 'PAM_TYPE':'open_session'}\n"
        "result=subprocess.run([str(program)], env=env, capture_output=True, text=True)\n"
        "assert result.returncode==0, result.stderr\n"
        "assert (leaf/'cgroup.procs').read_text()==str(pid)\n"
        "state=leaf.stat(); assert (state.st_uid,state.st_gid)==tuple(map(int,sys.argv[3:5]))\n"
    )
    namespace(
        sys.executable, wrapper, pam_program, pam_root,
        account.pw_uid, account.pw_gid,
    )
    print("PAM: lobo/root no-op; real mkdir then ordinary cgroup.procs stand-in passed")


def probe_launcher(module_dir, root, account):
    home = root / "launcher-home"
    home.mkdir(mode=0o755)
    runtime = root / "launcher-runtime"
    runtime.mkdir()
    service = root / "launcher-cgroup" / "service"
    service.mkdir(parents=True)
    procs = service / "cgroup.procs"
    procs.write_text("")
    interpreter = Path(sys.executable).resolve()
    helper = script(
        root / "helper.py",
        f"#!{interpreter}\n"
        "import json, os\n"
        "print(json.dumps({'uid': os.geteuid(), 'gid': os.getegid(), "
        "'supplementary': os.getgroups(), 'cwd': os.getcwd()}))\n",
    )
    source = built(module_dir, "aiagent-compose-program").read_text()
    header, body = source.split("!#\n", 1)
    assert body.count("/sys/fs/cgroup/aiagent/delegated") == 1
    body = body.replace("/sys/fs/cgroup/aiagent/delegated", str(service.parent))
    old_chdir = '(chdir "/home/aiagent")'
    old_exec = '(execl "/home/aiagent/.local/bin/gak-compose-lifecycle"'
    old_reconcile = '"/home/aiagent/.local/bin/gak-aiagent-reconcile"'
    assert body.count(old_chdir) == body.count(old_exec) == body.count(old_reconcile) == 1
    body = body.replace(old_chdir, '(chdir (string-append "/proc/self/fd/" (number->string (fileno home-port))))')
    body = body.replace(old_exec, '(execl (string-append "/proc/self/fd/" (number->string (fileno helper-port)))')
    body = body.replace(old_reconcile, '"/run/current-system/profile/bin/true"')
    body = body.replace("/home/aiagent", str(home)).replace("/run/aiagent", str(runtime))
    prefix = (
        "(setgroups #(42))\n"
        "(unless (equal? (getgroups) #(42)) (error \"probe group setup failed\"))\n"
        f"(let* ((home-port (open {json.dumps(str(home))} O_RDONLY)) "
        f"(helper-port (open {json.dumps(str(helper))} O_RDONLY)))\n"
    )
    probe = script(root / "launcher.scm", header + "!#\n" + prefix + body + ")\n")
    result = namespace(probe)
    identity = json.loads(result.stdout.strip())
    assert identity == {
        "uid": account.pw_uid,
        "gid": account.pw_gid,
        "supplementary": [],
        "cwd": str(home),
    }, identity
    assert procs.read_text().strip().isdigit()
    print("launcher: real setgroups/setgid/setuid cleared seeded group 42; preopened /proc/self/fd paths skip ancestor traversal")


def probe_graceful_stop(module_dir, root, account):
    service = root / "graceful-cgroup" / "service"
    service.mkdir(parents=True)
    procs = service / "cgroup.procs"
    procs.write_text("")
    interpreter = Path(sys.executable).resolve()
    helper = script(
        root / "graceful-helper.py",
        f"#!{interpreter}\n"
        "import json, os, sys\n"
        "print(json.dumps({'uid': os.geteuid(), 'gid': os.getegid(), "
        "'supplementary': os.getgroups(), 'args': sys.argv[1:], 'pid': os.getpid()}))\n",
    )
    source = built(module_dir, "aiagent-podman-stop-program").read_text()
    header, body = source.split("!#\n", 1)
    old_podman = '(execl "/run/current-system/profile/bin/podman"'
    assert body.count(old_podman) == body.count("/sys/fs/cgroup/aiagent/delegated") == 1
    body = body.replace("/sys/fs/cgroup/aiagent/delegated", str(service.parent))
    body = body.replace(old_podman,
                        '(execl (string-append "/proc/self/fd/" (number->string (fileno helper-port)))')
    prefix = f'(let ((helper-port (open {json.dumps(str(helper))} O_RDONLY)))\n'
    probe = script(root / "graceful-stop.scm", header + "!#\n" + prefix + body + ")\n")
    identity = json.loads(namespace(probe).stdout.strip())
    assert identity == {
        "uid": account.pw_uid,
        "gid": account.pw_gid,
        "supplementary": [],
        "args": ["stop", "--all", "--time", "10"],
        "pid": identity["pid"],
    }, identity
    assert procs.read_text() == str(identity["pid"])
    print("graceful Podman stop: real cgroup write and privilege drop; stop --all --time 10 reached")


def probe_home(module_dir, root, account):
    backing = root / "backing"
    backing.mkdir()
    home = root / "home"
    loop_access = namespace(
        sys.executable, "-c",
        "import errno, os\n"
        "try:\n"
        " fd=os.open('/dev/loop-control', os.O_RDWR); os.close(fd)\n"
        " raise AssertionError('loop-control unexpectedly accessible')\n"
        "except OSError as exc:\n"
        " assert exc.errno in (errno.EPERM, errno.EACCES)\n"
        " print(exc.errno)\n",
    ).stdout.strip()
    inner_store = built(module_dir, "aiagent-home-locked-program")
    inner_source = (
        inner_store.read_text()
        .replace("/var/lib/aiagent", str(backing))
        .replace("/home/aiagent", str(home))
        .replace("274877906944", "67108864")
    )
    inner = script(root / "home-inner.scm", inner_source)
    outer_source = built(module_dir, "aiagent-home-program").read_text()
    assert str(inner_store) in outer_source
    outer = script(
        root / "home-outer.scm",
        outer_source.replace("/var/lib/aiagent", str(backing)).replace(str(inner_store), str(inner)),
    )
    attempt = namespace(outer, check=False, timeout=30)
    assert attempt.returncode != 0 and "Wrong type argument" not in attempt.stderr
    assert "failed to setup loop device" in attempt.stderr
    assert (backing / "home.ext4").exists() and not (backing / "home.ext4.new").exists()
    assert home.is_dir() and namespace_owner(home)[2] == 0
    assert (backing / "home.lock").stat().st_mode & 0o777 == 0o600
    print(f"home: real mkdir/format/fsck passed; loop setup denied (errno {loop_access})")

    image = backing / "home.ext4"
    groups = [line for line in command(SBIN / "dumpe2fs", image).stdout.splitlines()
              if re.match(r"Group [0-9]+:", line)]
    assert groups and all("ITABLE_ZEROED" in line for line in groups), groups
    assert image.stat().st_blocks * 512 >= image.stat().st_size
    print("home: every ext4 group has ITABLE_ZEROED; allocation survived format")

    header, body = inner_source.split("!#\n", 1)
    mocked_mount = (
        "(define actual-system* system*)\n"
        "(let ((system* (lambda (cmd . args)\n"
        " (if (and (string-suffix? \"/timeout\" cmd)\n"
        "          (string-suffix? \"/mount\" (list-ref args 2)))\n"
        "     0 (apply actual-system* cmd args))))) "
        + body + ")\n"
    )
    mount_probe = script(root / "home-mock-mount.scm", header + "!#\n" + mocked_mount)
    namespace(mount_probe)
    assert namespace_owner(home) == (account.pw_uid, account.pw_gid, 700)
    print("home: post-mount chown/chmod passed with mount success mocked")

    mounted_harness = '''(use-modules (ice-9 popen) (ice-9 rdelim) (srfi srfi-1))
(define actual-system* system*)
(define actual-open-pipe* open-pipe*)
(define actual-close-pipe close-pipe)
(define actual-call-with-input-file call-with-input-file)
(define fake-findmnt #f)
(let ((system* (lambda (cmd . args)
  (if (and (string-suffix? "/timeout" cmd)
           (string-suffix? "/mountpoint" (list-ref args 2)))
      0 (apply actual-system* cmd args))))
      (open-pipe* (lambda (mode cmd . args)
        (if (any (lambda (arg) (string-suffix? "/findmnt" arg)) args)
            (begin (set! fake-findmnt (open-input-string "/dev/loop0\\n")) fake-findmnt)
            (apply actual-open-pipe* mode cmd args))))
      (close-pipe (lambda (port)
        (if (eq? port fake-findmnt) (begin (close-port port) 0)
            (actual-close-pipe port))))
      (call-with-input-file (lambda (file proc)
        (if (string-prefix? "/sys/block/" file)
            (proc (open-input-string IMAGE_PATH))
            (actual-call-with-input-file file proc))))) BODY)
'''.replace("IMAGE_PATH", json.dumps(str(backing / "home.ext4") + "\n")).replace("BODY", body)
    mounted_probe = script(root / "home-already-mounted.scm", header + "!#\n" + mounted_harness)
    namespace(mounted_probe)
    assert namespace_owner(home) == (account.pw_uid, account.pw_gid, 700)
    print("home: already-mounted source and ownership validation passed")

    sentinel = root / "sentinel.txt"
    sentinel.write_text("aiagent image data must survive hole reservation\n")
    command(SBIN / "debugfs", "-w", "-R", f"write {sentinel} /sentinel", image)
    before = root / "before.txt"
    after = root / "after.txt"
    command(SBIN / "debugfs", "-R", f"dump /sentinel {before}", image)
    expected = hashlib.sha256(before.read_bytes()).hexdigest()
    command(PROFILE / "fallocate", "--punch-hole", "--keep-size",
            "-o", str(60 * 1024**2), "-l", str(1024**2), image)
    assert image.stat().st_blocks * 512 < image.stat().st_size
    command(SBIN / "e2fsck", "-p", image)
    assert mocked_mount.count("(* blocks block-size)))") == 1
    short_space = script(root / "home-no-headroom.scm", header + "!#\n" +
                         mocked_mount.replace("(* blocks block-size)))", "0))"))
    refusal = namespace(short_space, check=False)
    assert refusal.returncode and "insufficient host free space to restore" in refusal.stderr
    assert image.stat().st_blocks * 512 < image.stat().st_size
    assert not (backing / "home.ext4.new").exists()
    print("home: existing-image headroom refusal leaves hole and no candidate")
    namespace(mount_probe)
    assert image.stat().st_blocks * 512 >= image.stat().st_size
    command(SBIN / "e2fsck", "-p", image)
    command(SBIN / "debugfs", "-R", f"dump /sentinel {after}", image)
    assert hashlib.sha256(after.read_bytes()).hexdigest() == expected
    print(f"home: existing-image hole restored; fsck clean; sentinel sha256 {expected}")

    drain_store = built(module_dir, "aiagent-cgroup-drain-program")
    podman_stop_store = built(module_dir, "aiagent-podman-stop-program")
    drain_marker = root / "drain-called"
    graceful_marker = root / "graceful-called"
    drain_stub = script(root / "drain-stub.sh", f"#!/bin/sh\nprintf '%s\\n' \"$1\" >> {drain_marker}\n")
    graceful_stub = script(root / "graceful-stub.sh",
                           f"#!/bin/sh\nprintf graceful >> {graceful_marker}\n")
    stop_source = built(module_dir, "aiagent-home-stop-locked-program").read_text()
    assert stop_source.count(str(drain_store)) == 1
    assert stop_source.count(str(podman_stop_store)) == 1
    stop_source = (stop_source.replace(str(drain_store), str(drain_stub))
                   .replace(str(podman_stop_store), str(graceful_stub))
                   .replace("/home/aiagent", str(home)))
    stop = script(root / "home-stop.scm", stop_source)
    failed = namespace(stop, check=False, timeout=10)
    assert failed.returncode != 0 and "Wrong type argument" not in failed.stderr
    assert drain_marker.read_text().splitlines() == ["all"]
    assert graceful_marker.read_text() == "graceful"
    header, body = stop_source.split("!#\n", 1)
    stop_mock = script(root / "home-mock-umount.scm", header + "!#\n" +
                       "(define real-system* system*)\n"
                       "(let ((system* (lambda (cmd . args)\n"
                       " (if (and (string-suffix? \"/timeout\" cmd)\n"
                       "          (string-suffix? \"/umount\" (list-ref args 2)))\n"
                       "     0 (apply real-system* cmd args))))) " + body + ")\n")
    namespace(stop_mock)
    assert drain_marker.read_text().splitlines() == ["all", "all"]
    assert graceful_marker.read_text() == "gracefulgraceful"
    assert namespace_owner(home)[2] == 0
    print("home stop: drain stubbed; real umount reached; post-unmount chmod passed with umount mocked")
    return home


def probe_stop_and_shell(module_dir, root):
    lock = root / "stop.lock"
    lock.write_text("")
    lock.chmod(0o600)
    marker = root / "stopped"
    child = script(root / "stop-child.sh", f"#!/bin/sh\nprintf stopped > {marker}\n")
    source = built(module_dir, "aiagent-home-stop-program").read_text()
    match = re.search(r"/gnu/store/[a-z0-9]+-aiagent-home-stop-locked", source)
    assert match is not None
    stop = script(root / "stop-wrapper.scm", source.replace("/var/lib/aiagent/home.lock", str(lock)).replace(match.group(0), str(child)))
    namespace(stop)
    assert marker.exists()
    shell = built(module_dir, "aiagent-shell-program")
    namespace(shell, "-c", 'test "$HOME" = /home/aiagent && test "$XDG_RUNTIME_DIR" = /run/aiagent')
    print("home stop wrapper and agent shell: passed")


def main():
    module_dir = Path(sys.argv[1]).resolve()
    assert (module_dir / "aiagent/host.scm").is_file()
    native_mount = os.readlink("/proc/self/ns/mnt")
    agent_mount = namespace(PROFILE / "readlink", "/proc/self/ns/mnt").stdout.strip()
    assert native_mount != agent_mount, "podman unshare needs an isolated mount namespace"
    print("namespace root is not host root; ordinary files do not test kernel cgroup delegation")
    account = pwd.getpwnam("aiagent")
    scratch = Path.home() / ".cache/gak-aiagent-host"
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="root-path-", dir=scratch) as name:
        root = Path(name)
        home = root / "home"
        try:
            probe_runtime_cgroup_pam(module_dir, root, account)
            probe_launcher(module_dir, root, account)
            probe_graceful_stop(module_dir, root, account)
            probe_home(module_dir, root, account)
            probe_stop_and_shell(module_dir, root)
        finally:
            namespace(PROFILE / "chown", "-R", "0:0", root)
            if home.exists():
                namespace(PROFILE / "chmod", "700", home)


if __name__ == "__main__":
    main()
