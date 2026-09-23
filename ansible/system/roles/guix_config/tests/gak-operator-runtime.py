#!/usr/bin/env python3
"""Exercise the built media runtime waiter with real private tmpfs mounts."""

import json
import os
from pathlib import Path
import pwd
import subprocess
import sys
import tempfile
import time


PROFILE = Path("/run/current-system/profile/bin")


def command(*args, check=True):
    result = subprocess.run(args, capture_output=True, text=True)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr[-400:]}")
    return result


def built(system, modules):
    expression = f'(begin (load {json.dumps(str(system))}) %gak-operator-runtime-program)'
    result = subprocess.run(
        ["guix", "build", "-L", str(modules), "-e", expression],
        capture_output=True, text=True,
        env={**os.environ, "GUILE_AUTO_COMPILE": "0"},
        check=True,
    )
    return Path(result.stdout.strip().splitlines()[-1])


def mount_count(path):
    return sum(line.split()[4] == str(path) for line in Path("/proc/self/mountinfo").read_text().splitlines())


def mount_runtime(path, uid, gid, mode):
    path.mkdir()
    command(PROFILE / "mount", "-t", "tmpfs", "-o",
            f"uid={uid},gid={gid},mode={mode:o},nosuid,nodev", "tmpfs", path)
    assert mount_count(path) == 1
    (path / "sentinel").write_text("elogind owns this mount\n")


def one_case(program, root, label, *, delay=None, uid=1000, gid=None, mode=0o700):
    place = root / label
    place.mkdir()
    runtime = place / "1000"
    source = program.read_text().replace("/run/user", str(place))
    assert source.count("(deadline (+ started 180))") == 1
    assert source.count("(>= (- (uptime-seconds) started) 30)") == 1
    source = source.replace("(deadline (+ started 180))", "(deadline (+ started 5))")
    source = source.replace("(>= (- (uptime-seconds) started) 30)",
                            "(>= (- (uptime-seconds) started) 2)")
    header, body = source.split("!#\n", 1)
    request_marker = place / "linger-request"
    wrapper = (
        "(define real-system* system*)\n"
        "(let ((system* (lambda (cmd . args)\n"
        " (if (member \"enable-linger\" args)\n"
        f"     (begin (call-with-output-file {json.dumps(str(request_marker))} "
        "(lambda (port) (display \"request\\n\" port))) 0)\n"
        "     (apply real-system* cmd args))))) " + body + ")\n"
    )
    executable = place / "runtime.scm"
    executable.write_text(header + "!#\n" + wrapper)
    executable.chmod(0o755)
    mounted = False
    process = None
    try:
        if delay == 0:
            mount_runtime(runtime, uid, gid, mode)
            mounted = True
        process = subprocess.Popen([str(executable)], stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True)
        if delay is not None and delay > 0:
            time.sleep(delay)
            assert process.poll() is None, f"{label}: waiter exited before mount"
            mount_runtime(runtime, uid, gid, mode)
            mounted = True
        stdout, stderr = process.communicate(timeout=12)
        requests = request_marker.read_text().splitlines() if request_marker.exists() else []
        if label in ("before", "during", "after"):
            assert process.returncode == 0, (label, stderr)
            assert (runtime / "sentinel").read_text() == "elogind owns this mount\n"
            assert requests == (["request"] if label == "after" else []), requests
        elif label == "never":
            assert process.returncode != 0 and "operator runtime tmpfs " in stderr and " is missing" in stderr, stderr
            assert "loginctl show-user" in stderr and "sudo herd enable gak-compose && sudo herd start gak-compose" in stderr
            assert requests == ["request"], requests
        else:
            assert process.returncode != 0 and "ownership or mode is wrong" in stderr, stderr
            assert (runtime / "sentinel").read_text() == "elogind owns this mount\n"
            assert requests == [], requests
        assert mount_count(runtime) == int(mounted), f"{label}: stacked or lost mount"
        print(f"{label}: {'ready' if process.returncode == 0 else 'refused'}; "
              f"linger requests={len(requests)}; mounts={mount_count(runtime)}")
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        if mounted:
            command(PROFILE / "umount", runtime)
        assert mount_count(runtime) == 0, f"{label}: mount left behind"


def inner(program, root):
    account = pwd.getpwuid(1000)
    one_case(program, root, "before", delay=0, gid=account.pw_gid)
    one_case(program, root, "during", delay=0.5, gid=account.pw_gid)
    one_case(program, root, "after", delay=2.5, gid=account.pw_gid)
    one_case(program, root, "never")
    one_case(program, root, "wrong-owner", delay=0, uid=0, gid=0)
    one_case(program, root, "wrong-mode", delay=0, gid=account.pw_gid, mode=0o755)


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "--inner":
        inner(Path(sys.argv[2]), Path(sys.argv[3]))
        return
    system = Path(sys.argv[1]).resolve()
    modules = Path(sys.argv[2]).resolve()
    assert system.is_file() and (modules / "aiagent/host.scm").is_file()
    assert os.readlink("/proc/self/ns/mnt") != command(
        "podman", "unshare", PROFILE / "readlink", "/proc/self/ns/mnt"
    ).stdout.strip()
    scratch = Path.home() / ".cache/gak-aiagent-host"
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="media-runtime-", dir=scratch) as name:
        result = command("podman", "unshare", sys.executable, __file__,
                         "--inner", built(system, modules), name)
        print(result.stdout, end="")


if __name__ == "__main__":
    main()
