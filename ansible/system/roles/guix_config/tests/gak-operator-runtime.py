#!/usr/bin/env python3
"""Exercise the built media runtime initializer without touching live /run."""

import json
import os
from pathlib import Path
import pwd
import subprocess
import sys
import tempfile


PROFILE = Path("/run/current-system/profile/bin")


def command(*args, check=True):
    result = subprocess.run(args, capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr[-400:]}")
    return result


def namespace(*args, check=True):
    return command("podman", "unshare", *map(str, args), check=check)


def built(system, modules):
    expression = f'(begin (load {json.dumps(str(system))}) %gak-operator-runtime-program)'
    result = subprocess.run(
        ["guix", "build", "-L", str(modules), "-e", expression],
        capture_output=True, text=True,
        env={**os.environ, "GUILE_AUTO_COMPILE": "0"},
        check=True,
    )
    return Path(result.stdout.strip().splitlines()[-1])


def probe(program, root, label, nonempty=False, mounted=False):
    parent = root / label
    parent.mkdir()
    runtime = parent / "1000"
    marker = root / f"{label}-mounted"
    count = root / f"{label}-mount-count"
    if nonempty or mounted:
        runtime.mkdir()
    if nonempty:
        (runtime / "sentinel").write_text("keep")
    if mounted:
        marker.write_text("mounted")

    source = program.read_text()
    assert "/run/user" in source
    header, body = source.replace("/run/user", str(parent)).split("!#\n", 1)
    harness = '''(define actual-system* system*)
(let ((system* (lambda (cmd . args)
  (cond ((string-suffix? "/mountpoint" cmd)
          (if (file-exists? MARKER) 0 8192))
        ((string-suffix? "/findmnt" cmd)
          (if (file-exists? MARKER) 0 256))
        ((string-suffix? "/mount" cmd)
          (let ((options (list-ref args 3)))
            (unless (and (string? options)
                         (string-contains options "nosuid,nodev,mode=0700,uid=1000")
                         (string-contains options ",size=10%"))
              (error "invalid runtime mount options")))
          (let ((port (open-file COUNT "a")))
            (display "mount\\n" port) (close-port port))
          (call-with-output-file MARKER (lambda (port) (display "mounted" port)))
          0)
        (else (apply actual-system* cmd args)))))) BODY)
'''.replace("MARKER", json.dumps(str(marker))).replace("COUNT", json.dumps(str(count))).replace("BODY", body)
    wrapper = root / f"{label}.scm"
    wrapper.write_text(header + "!#\n" + harness)
    wrapper.chmod(0o755)
    result = namespace(wrapper, check=False)
    return result, runtime, marker, count


def main():
    system = Path(sys.argv[1]).resolve()
    modules = Path(sys.argv[2]).resolve()
    assert system.is_file() and (modules / "aiagent/host.scm").is_file()
    assert os.readlink("/proc/self/ns/mnt") != namespace(PROFILE / "readlink", "/proc/self/ns/mnt").stdout.strip()
    account = pwd.getpwuid(1000)
    scratch = Path.home() / ".cache/gak-aiagent-host"
    scratch.mkdir(parents=True, exist_ok=True)
    program = built(system, modules)
    with tempfile.TemporaryDirectory(prefix="media-runtime-", dir=scratch) as name:
        root = Path(name)
        try:
            first, runtime, marker, count = probe(program, root, "fresh")
            assert first.returncode == 0, first.stderr[-400:]
            owner = namespace(PROFILE / "stat", "-c", "%u %g %a", runtime).stdout.strip()
            assert owner == f"1000 {account.pw_gid} 700", owner
            assert count.read_text().splitlines() == ["mount"]
            again = namespace(root / "fresh.scm")
            assert again.returncode == 0 and count.read_text().splitlines() == ["mount"]
            print("fresh directory: mkdir/chown/chmod/mount arguments passed; existing mount reused")

            nonempty, runtime, marker, count = probe(program, root, "nonempty", nonempty=True)
            assert nonempty.returncode != 0 and "not empty" in nonempty.stderr
            assert (runtime / "sentinel").read_text() == "keep" and not marker.exists()
            print("nonempty plain directory: refused without covering data")

            wrong_owner, runtime, marker, count = probe(program, root, "wrong-owner", mounted=True)
            assert wrong_owner.returncode != 0 and "ownership or mode is wrong" in wrong_owner.stderr
            assert marker.exists() and not count.exists()
            print("existing mount with wrong owner: refused without remount")
        finally:
            namespace(PROFILE / "chown", "-R", "0:0", root)


if __name__ == "__main__":
    main()
