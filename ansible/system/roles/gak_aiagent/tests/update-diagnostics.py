#!/usr/bin/env python3
"""Check the real shared updater's hook and provider diagnostic privacy boundary."""

import os
from pathlib import Path
import subprocess
import tempfile


ROLE = Path(__file__).resolve().parents[1]
SHARED = ROLE.parent / "gak_compose/files/gak-services.py"
PROBE = '''#!/usr/bin/env python3
import importlib.machinery
import os
from pathlib import Path
from types import SimpleNamespace

shared = importlib.machinery.SourceFileLoader("gak_services_diagnostic_probe", os.environ["SHARED_SOURCE"]).load_module()
root = Path(os.environ["DIAGNOSTIC_TEST_ROOT"])
runtime = shared.build_runtime()
project = SimpleNamespace(name="agent", directory=root, root=root)
result = shared.run_hook(runtime, project, [str(root / "readiness")], timeout=5, label="readiness")
assert result.status == 17
detail = shared.provider_detail(runtime, shared.Result(1, "", "provider-secret-sentinel"))
print(detail)
'''
PODMAN = '''#!/bin/sh
if [ "$1" = compose ] && [ "$2" = version ]; then exit 0; fi
exit 99
'''
READINESS = '''#!/bin/sh
printf 'readiness-hook-output-sentinel\\n'
printf 'readiness-hook-stderr-sentinel\\n' >&2
exit 17
'''


def run_probe(root, *, hook=False, provider=False):
    env = dict(os.environ, SHARED_SOURCE=str(SHARED), DIAGNOSTIC_TEST_ROOT=str(root),
               HOME=str(root), GAK_COMPOSE_PODMAN=str(root / "podman"))
    env.pop("GAK_SERVICES_SHOW_HOOK_OUTPUT", None)
    env.pop("GAK_SERVICES_SHOW_PROVIDER_ERRORS", None)
    if hook:
        env["GAK_SERVICES_SHOW_HOOK_OUTPUT"] = "1"
    if provider:
        env["GAK_SERVICES_SHOW_PROVIDER_ERRORS"] = "1"
    return subprocess.run([root / "probe"], env=env, capture_output=True, text=True, timeout=10)


def main():
    with tempfile.TemporaryDirectory(prefix="aiagent-update-diagnostics-", dir=Path.home() / ".cache") as scratch:
        root = Path(scratch)
        for name, body in (("probe", PROBE), ("podman", PODMAN), ("readiness", READINESS)):
            path = root / name
            path.write_text(body)
            path.chmod(0o755)
        quiet = run_probe(root)
        assert quiet.returncode == 0, quiet.stderr
        assert "readiness-hook-output-sentinel" not in quiet.stdout + quiet.stderr
        assert "readiness-hook-stderr-sentinel" not in quiet.stdout + quiet.stderr
        assert "provider-secret-sentinel" not in quiet.stdout + quiet.stderr
        assert "GAK_SERVICES_SHOW_PROVIDER_ERRORS" in quiet.stdout

        verbose = run_probe(root, hook=True)
        assert verbose.returncode == 0, verbose.stderr
        assert "readiness-hook-output-sentinel" in verbose.stdout
        assert "readiness-hook-stderr-sentinel" in verbose.stderr
        assert "provider-secret-sentinel" not in verbose.stdout + verbose.stderr

        explicit = run_probe(root, provider=True)
        assert explicit.returncode == 0, explicit.stderr
        assert "provider-secret-sentinel" in explicit.stdout
        assert "readiness-hook-output-sentinel" not in explicit.stdout + explicit.stderr
        print("shared updater default hides hook and provider diagnostics")
        print("verbose hook flag streams only hook output; provider stderr requires separate opt-in")


if __name__ == "__main__":
    main()
