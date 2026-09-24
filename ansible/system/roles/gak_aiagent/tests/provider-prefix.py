#!/usr/bin/env python3
"""Exercise one-time provider seeding, selected versions, absence, and repair."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROLE = Path(__file__).resolve().parents[1]
SOURCE = ROLE / "files/image/bin/aiagent-provider-prefix"
PI = ROLE / "files/image/bin/pi"
PACKAGES = {
    "@anthropic-ai/claude-code": {"claude": "bin/claude.js"},
    "@openai/codex": {"codex": "bin/codex.js"},
    "opencode-ai": {"opencode": "bin/opencode.js"},
    "@earendil-works/pi-coding-agent": {"pi": "dist/bundle/cli.js"},
    "npm-check-updates": {"ncu": "build/cli.js", "npm-check-updates": "build/cli.js"},
}


def package_dir(prefix, name):
    return prefix / "lib/node_modules" / name


def write_package(prefix, name, bins, version):
    package = package_dir(prefix, name)
    package.mkdir(parents=True, exist_ok=True)
    (package / "package.json").write_text(json.dumps({"name": name, "version": version, "bin": bins}))
    (prefix / "bin").mkdir(exist_ok=True)
    for command, entry in bins.items():
        executable = package / entry
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        link = prefix / "bin" / command
        link.unlink(missing_ok=True)
        link.symlink_to(os.path.relpath(executable, link.parent))


def invoke(command, *args):
    return subprocess.run([command, *args], text=True, capture_output=True, timeout=10)


def main():
    with tempfile.TemporaryDirectory(prefix="provider-prefix-", dir=Path.home() / ".cache") as scratch:
        root = Path(scratch)
        home = root / "home"
        home.mkdir()
        seed = root / "seed"
        (seed / "lib/node_modules").mkdir(parents=True)
        (seed / "bin").mkdir()
        for name, bins in PACKAGES.items():
            write_package(seed, name, bins, "1.0.0")
        source = SOURCE.read_text()
        source = source.replace('HOME = Path("/home/node")', f"HOME = Path({str(home)!r})")
        source = source.replace('SEED = Path("/opt/aiagent-provider-seed")', f"SEED = Path({str(seed)!r})")
        manager = root / "aiagent-provider-prefix"
        manager.write_text(source)
        manager.chmod(0o755)
        prefix = home / ".local/aiagent/npm"
        credential = home / ".config/auth.json"
        credential.parent.mkdir()
        credential.write_text("synthetic credential sentinel")

        assert invoke(manager, "check-seed").returncode == 0
        result = invoke(manager, "ensure")
        assert result.returncode == 0, result.stderr
        assert invoke(manager, "check").returncode == 0
        assert (prefix / ".aiagent-seed.json").is_file()
        assert not list(prefix.parent.glob(".npm-seed-*"))
        assert "claude: 1.0.0 (image seed 1.0.0)" in invoke(manager, "status").stdout
        (prefix / "bin").chmod(0o500)
        assert "not writable" in invoke(manager, "check").stderr
        (prefix / "bin").chmod(0o700)
        assert invoke(manager, "check").returncode == 0

        write_package(prefix, "@openai/codex", {"codex": "dist/new-cli.js"}, "2.0.0")
        assert invoke(manager, "ensure").returncode == 0
        assert "codex: 2.0.0 (image seed 1.0.0)" in invoke(manager, "status").stdout
        assert credential.read_text() == "synthetic credential sentinel"

        stale = home / ".local/bin/claude"
        stale.parent.mkdir(parents=True)
        stale.write_text("#!/bin/sh\nexit 99\n")
        stale.chmod(0o755)
        shutil.rmtree(package_dir(prefix, "@anthropic-ai/claude-code"))
        (prefix / "bin/claude").unlink()
        assert invoke(manager, "ensure").returncode == 0
        assert "claude: absent (image seed 1.0.0)" in invoke(manager, "status").stdout
        selected_path = f"{prefix / 'bin'}:/usr/local/bin:/usr/bin:/bin"
        assert subprocess.run(["sh", "-c", "command -v claude"],
                              env={"PATH": selected_path}, capture_output=True).returncode != 0

        pi_source = PI.read_text().replace(
            "/home/node/.local/aiagent/npm", str(prefix)
        ).replace("/opt/pi-node/node", str(root / "pi-node"))
        pi = root / "pi"
        pi.write_text(pi_source)
        pi.chmod(0o755)
        node = root / "pi-node"
        node.write_text('''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
Path(os.environ["PI_TEST_LOG"]).write_text(json.dumps(sys.argv[1:]))
''')
        node.chmod(0o755)
        env = dict(os.environ, PI_TEST_LOG=str(root / "pi-args"))
        assert subprocess.run([pi, "--version"], env=env).returncode == 0
        assert json.loads((root / "pi-args").read_text()) == [
            str(package_dir(prefix, "@earendil-works/pi-coding-agent") / "dist/bundle/cli.js"),
            "--version",
        ]
        write_package(prefix, "@earendil-works/pi-coding-agent", {"pi": "bin/updated.js"}, "2.0.0")
        assert subprocess.run([pi, "--help"], env=env).returncode == 0
        assert json.loads((root / "pi-args").read_text())[0].endswith("/bin/updated.js")
        shutil.rmtree(package_dir(prefix, "@earendil-works/pi-coding-agent"))
        (prefix / "bin/pi").unlink()
        assert subprocess.run([pi], env=env, capture_output=True).returncode == 127
        assert invoke(manager, "ensure").returncode == 0

        for name, bins in PACKAGES.items():
            package = package_dir(prefix, name)
            if package.exists():
                shutil.rmtree(package)
            for command in bins:
                (prefix / "bin" / command).unlink(missing_ok=True)
        assert invoke(manager, "ensure").returncode == 0
        assert "codex: absent" in invoke(manager, "status").stdout
        assert invoke(manager, "reseed").returncode == 0

        (prefix / "bin/ncu").unlink()
        assert invoke(manager, "ensure").returncode == 1
        assert "incomplete" in invoke(manager, "ensure").stderr
        assert invoke(manager, "reseed").returncode == 0
        assert list(prefix.parent.glob("npm.before-reseed-*"))
        assert credential.read_text() == "synthetic credential sentinel"

        (prefix / ".aiagent-seed.json").write_text("broken")
        assert invoke(manager, "ensure").returncode == 1
        assert "marker" in invoke(manager, "ensure").stderr
        assert invoke(manager, "reseed").returncode == 0

        interrupted = prefix.parent / "npm.before-reseed-interrupted"
        prefix.rename(interrupted)
        assert invoke(manager, "ensure").returncode == 1
        assert "interrupted" in invoke(manager, "ensure").stderr
        assert not prefix.exists()
        assert invoke(manager, "reseed").returncode == 0
        assert interrupted.exists()

        archives = root / "retained-prefixes"
        archives.mkdir()
        for backup in prefix.parent.glob("npm.before-reseed-*"):
            backup.rename(archives / backup.name)
        shutil.rmtree(prefix)
        incomplete = prefix.parent / ".npm-seed-abandoned"
        incomplete.mkdir()
        assert invoke(manager, "ensure").returncode == 1
        assert "incomplete" in invoke(manager, "ensure").stderr
        assert invoke(manager, "reseed").returncode == 0
        assert list(prefix.parent.glob("npm.incomplete-*"))
        assert invoke(manager, "check").returncode == 0
        print("one-time seed, updated version, intentional absence, and Pi selected-bin wrapper passed")
        print("corrupt links and marker, interrupted reseed, and incomplete staging required explicit repair")
        print("reseed retained previous prefixes and synthetic credential state")


if __name__ == "__main__":
    main()
