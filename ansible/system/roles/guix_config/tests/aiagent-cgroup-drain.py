#!/usr/bin/env python3
"""Exercise built agent stop programs against a disposable cgroup v2 child."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


PROFILE = Path("/run/current-system/profile/bin")
CGROUP = Path("/sys/fs/cgroup/conmon/gak-aiagent-stop-probe")
PRODUCTION_CGROUP = "/sys/fs/cgroup/aiagent/delegated"


def command(*args, check=True, **kwargs):
    result = subprocess.run(args, capture_output=True, text=True, **kwargs)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr[-600:]}")
    return result


def namespace(*args, **kwargs):
    return command("podman", "unshare", *map(str, args), **kwargs)


def built(modules, name):
    result = command(
        "guix", "build", "-L", modules, "-e", f"(@@ (aiagent host) {name})",
        env={**os.environ, "GUILE_AUTO_COMPILE": "0"},
    )
    return Path(result.stdout.strip().splitlines()[-1])


def script(path, source):
    path.write_text(source)
    path.chmod(0o755)
    return path


def drain_copy(source, path, target, seconds):
    assert source.count(PRODUCTION_CGROUP) == 3
    assert source.count("(deadline (+ (uptime-seconds) 60))") == 1
    return script(
        path,
        source.replace(PRODUCTION_CGROUP, str(target)).replace(
            "(deadline (+ (uptime-seconds) 60))",
            f"(deadline (+ (uptime-seconds) {seconds}))",
        ),
    )


def stop_copy(source, path, drain_store, drain, home, marker, events):
    assert source.count(str(drain_store)) == 1
    assert source.count("/home/aiagent") == 2
    header, body = source.replace(str(drain_store), str(drain)).replace(
        "/home/aiagent", str(home)
    ).split("!#\n", 1)
    wrapper = (
        "(define real-system* system*)\n"
        "(let ((system* (lambda (cmd . args)\n"
        " (if (and (string-suffix? \"/timeout\" cmd)\n"
        "          (string-suffix? \"/umount\" (list-ref args 2)))\n"
        f"     (begin (call-with-input-file {json.dumps(str(events))}\n"
        "              (lambda (port)\n"
        "                (unless (and (eq? (read port) 'populated)\n"
        "                             (= (read port) 0))\n"
        "                  (error \"unmount before populated 0\"))))\n"
        f"            (call-with-output-file {json.dumps(str(marker))}\n"
        "              (lambda (port) (display \"unmount reached\" port))) 0)\n"
        "     (apply real-system* cmd args))))) " + body + ")\n"
    )
    return script(path, header + "!#\n" + wrapper)


def populated(path):
    return "populated 1" in (path / "cgroup.events").read_text().splitlines()


def detached_sleep(path):
    process = subprocess.Popen(
        [PROFILE / "sleep", "3600"], start_new_session=True,
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    (path / "cgroup.procs").write_text(str(process.pid))
    assert populated(CGROUP)
    return process


def test_real_cgroup(drain_store, stop_store, root):
    assert not CGROUP.exists(), "scratch cgroup already exists"
    assert CGROUP.parent.is_dir() and CGROUP.parent.stat().st_uid == os.getuid()
    CGROUP.mkdir()
    processes = []
    home = root / "home"
    home.mkdir(mode=0o700)
    try:
        service = CGROUP / "service"
        runtime = service / "runtime"
        ssh = CGROUP / "ssh-probe"
        service.mkdir()
        runtime.mkdir()
        ssh.mkdir()
        helper_survivor = detached_sleep(runtime)
        ssh_survivor = detached_sleep(ssh)
        processes.extend((helper_survivor, ssh_survivor))

        drain = drain_copy(drain_store.read_text(), root / "drain.scm", CGROUP, 3)
        namespace(drain, "service")
        helper_survivor.wait(timeout=5)
        assert not populated(service) and populated(CGROUP)
        assert service.exists() and not runtime.exists()
        assert ssh_survivor.poll() is None
        print("service drain: detached helper survivor killed; runtime cgroup removed; SSH survivor retained")

        marker = root / "unmounted"
        stop = stop_copy(stop_store.read_text(), root / "stop.scm", drain_store,
                         drain, home, marker, CGROUP / "cgroup.events")
        namespace(stop)
        ssh_survivor.wait(timeout=5)
        assert marker.read_text() == "unmount reached"
        assert not populated(CGROUP)
        assert service.exists() and not ssh.exists()
        assert home.stat().st_mode & 0o777 == 0
        print("home stop: detached SSH survivor killed; SSH leaf removed; populated 0 preceded mocked unmount")
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=5)
        namespace(PROFILE / "chmod", "700", home)
        if CGROUP.exists():
            (CGROUP / "cgroup.kill").write_text("1")
            for path in (CGROUP / "service/runtime", CGROUP / "service",
                         CGROUP / "ssh-probe", CGROUP):
                if not path.exists():
                    continue
                for _ in range(20):
                    try:
                        path.rmdir()
                        break
                    except OSError:
                        time.sleep(0.1)
                else:
                    raise AssertionError(f"scratch cgroup remains: {path}")


def test_stuck_cgroup(drain_store, stop_store, root):
    fake = root / "stuck"
    fake.mkdir()
    (fake / "cgroup.events").write_text("populated 1\nfrozen 0\n")
    (fake / "cgroup.procs").write_text("424242\n")
    (fake / "cgroup.kill").write_text("")
    home = root / "stuck-home"
    home.mkdir(mode=0o700)
    marker = root / "wrong-unmount"
    drain = drain_copy(drain_store.read_text(), root / "stuck-drain.scm", fake, 2)
    stop = stop_copy(stop_store.read_text(), root / "stuck-stop.scm", drain_store,
                     drain, home, marker, fake / "cgroup.events")
    started = time.monotonic()
    result = namespace(stop, check=False)
    elapsed = time.monotonic() - started
    assert result.returncode != 0 and 2 <= elapsed < 8, (elapsed, result.stderr)
    assert "remaining PIDs" in result.stderr and "424242" in result.stderr
    assert not marker.exists() and home.stat().st_mode & 0o777 == 0o700
    print(f"stuck drain: failed after {elapsed:.1f}s with PID 424242; unmount skipped")


def test_populated_leaf(drain_store, root):
    fake = root / "leaves"
    service = fake / "service"
    busy = fake / "ssh-busy"
    empty = fake / "ssh-empty"
    runtime = service / "runtime"
    for path in (fake, service, busy, empty, runtime):
        path.mkdir(parents=True, exist_ok=True)
        (path / "cgroup.events").write_text(
            "populated 1\n" if path == busy else "populated 0\n"
        )
        (path / "cgroup.procs").write_text("424242\n" if path == busy else "")
    (fake / "cgroup.kill").write_text("")
    drain = drain_copy(drain_store.read_text(), root / "leaf-drain.scm", fake, 2)
    header, body = drain.read_text().split("!#\n", 1)
    stand_in = script(root / "leaf-files.scm", header + "!#\n" +
                     "(define real-rmdir rmdir)\n"
                     "(let ((rmdir (lambda (path)\n"
                     " (for-each (lambda (name)\n"
                     "   (let ((file (string-append path \"/\" name)))\n"
                     "     (when (file-exists? file) (delete-file file))))\n"
                     "   '(\"cgroup.events\" \"cgroup.procs\" \"cgroup.kill\"))\n"
                     " (real-rmdir path)))) " + body + ")\n")
    namespace(stand_in, "all")
    assert busy.exists() and service.exists()
    assert not empty.exists() and not runtime.exists()
    print("leaf cleanup: populated SSH leaf retained; empty SSH and runtime leaves removed")


def main():
    modules = Path(sys.argv[1]).resolve()
    assert (modules / "aiagent/host.scm").is_file()
    assert os.readlink("/proc/self/ns/user") != namespace(
        PROFILE / "readlink", "/proc/self/ns/user"
    ).stdout.strip()
    root = Path.home() / ".cache/gak-aiagent-host"
    root.mkdir(parents=True, exist_ok=True)
    drain_store = built(modules, "aiagent-cgroup-drain-program")
    stop_store = built(modules, "aiagent-home-stop-locked-program")
    with tempfile.TemporaryDirectory(prefix="cgroup-drain-", dir=root) as name:
        scratch = Path(name)
        test_real_cgroup(drain_store, stop_store, scratch)
        test_stuck_cgroup(drain_store, stop_store, scratch)
        test_populated_leaf(drain_store, scratch)


if __name__ == "__main__":
    main()
