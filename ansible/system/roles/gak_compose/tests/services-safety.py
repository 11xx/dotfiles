"""Focused subprocess and deadline regression probes; no real containers."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

path = Path(__file__).resolve().parents[1] / "files/gak-services.py"
spec = importlib.util.spec_from_file_location("updater", path)
updater = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = updater
spec.loader.exec_module(updater)


class Safety(unittest.TestCase):
    def test_dead_leader_does_not_leave_its_child_running(self):
        with tempfile.TemporaryDirectory(prefix="gak-safety-") as root:
            pidfile = Path(root) / "child"
            proc = subprocess.Popen(
                [sys.executable, "-c", "import os,signal,time,pathlib,sys; "
                 "pid=os.fork(); "
                 "sys.exit(0) if pid else None; "
                 "signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                 "pathlib.Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(120)", str(pidfile)],
                start_new_session=True,
            )
            proc.wait(timeout=5)
            deadline = time.monotonic() + 5
            while not pidfile.exists() and time.monotonic() < deadline:
                time.sleep(.01)
            self.assertTrue(pidfile.exists())
            child = int(pidfile.read_text())
            try:
                updater.stop_process(proc, grace=.1)
                time.sleep(.1)
                status = Path(f"/proc/{child}/stat")
                self.assertTrue(not status.exists() or status.read_text().split()[2] == "Z")
            finally:
                try:
                    os.kill(child, 9)
                except ProcessLookupError:
                    pass

    def test_expired_budget_fails_before_inspection(self):
        from types import SimpleNamespace
        with self.assertRaises(updater.ProjectFailure):
            updater.time_budget(SimpleNamespace(inspect_timeout=60), time.monotonic() - 1)


if __name__ == "__main__":
    unittest.main()
