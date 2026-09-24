#!/usr/bin/env python3
"""Exercise Pi's terminal and login menu in a disposable image container."""

import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import termios
import time


image = sys.argv[1]
name = f"pi-tui-probe-{os.getpid()}"
pid, terminal = pty.fork()
if pid == 0:
    os.execvp(
        "podman",
        [
            "podman", "run", "--rm", "-it", "--name", name,
            "--entrypoint", "pi", "-e", "TERM=xterm-256color", image,
        ],
    )

fcntl.ioctl(terminal, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
reaped = False


def read_until(marker):
    global reaped
    output = bytearray()
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        ready, _, _ = select.select([terminal], [], [], 0.1)
        if ready:
            try:
                output.extend(os.read(terminal, 65536))
            except OSError:
                pass
        if marker in output:
            return
        finished, status = os.waitpid(pid, os.WNOHANG)
        if finished:
            reaped = True
            raise RuntimeError(f"Pi exited {os.waitstatus_to_exitcode(status)} before {marker!r}")
    raise RuntimeError(f"Pi did not draw {marker!r}")


try:
    read_until(b"Warning: No models available")
    print("prompt: drawn")
    os.write(terminal, b"/login\r")
    read_until(b"Select authentication method:")
    print("/login: provider menu drawn")
    os.write(terminal, b"\x1b")
    time.sleep(0.5)
    os.write(terminal, b"\x04")
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        finished, status = os.waitpid(pid, os.WNOHANG)
        if finished:
            reaped = True
            exit_code = os.waitstatus_to_exitcode(status)
            print(f"quit: exit {exit_code}")
            if exit_code != 0:
                raise RuntimeError("Pi did not exit cleanly")
            break
        time.sleep(0.1)
    else:
        raise RuntimeError("Pi did not exit after Ctrl+D")
except RuntimeError as exc:
    print(f"fail: {exc}", file=sys.stderr)
    raise SystemExit(1)
finally:
    if not reaped:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
    subprocess.run(["podman", "rm", "-f", name], stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, check=False)
