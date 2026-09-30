#!/usr/bin/env python3
"""Verify pinned collection builds ignore mutable source checkout content."""

import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import yaml


SYSTEM = Path(__file__).resolve().parents[2]
source_value = os.environ.get("AIAGENT_REMOTE_COLLECTION_SOURCE")
if not source_value:
    raise SystemExit("set AIAGENT_REMOTE_COLLECTION_SOURCE to a local agent-remote Git repository")
SOURCE = Path(source_value).resolve()
PIN = (SYSTEM / "collection-pin").read_text().strip()
if not re.fullmatch(r"[0-9a-f]{40}", PIN):
    raise SystemExit("collection-pin must contain one full Git commit ID")
CACHE = Path.home() / ".cache"
CACHE.mkdir(parents=True, exist_ok=True)


def run(args, *, env=None, check=True):
    result = subprocess.run(args, capture_output=True, text=True, env=env)
    if check and result.returncode:
        raise RuntimeError(f"{' '.join(map(str, args))}\n{result.stdout}{result.stderr}")
    return result


def git(repository, *args):
    return run(["git", "-C", str(repository), *args]).stdout.strip()


def git_bytes(repository, *args):
    return subprocess.run(
        ["git", "-C", str(repository), *args], check=True, capture_output=True
    ).stdout


def project(root, name, *, pin_contents=PIN):
    system = root / name / "ansible/system"
    (system / "bin").mkdir(parents=True)
    shutil.copy2(SYSTEM / "bin/install-remote-collection", system / "bin/install-remote-collection")
    if pin_contents is not None:
        (system / "collection-pin").write_text(pin_contents)
    home = root / f"home-{name}"
    (home / ".cache").mkdir(parents=True)
    env = dict(os.environ, HOME=str(home), AIAGENT_REMOTE_COLLECTION_SOURCE=str(SOURCE_COPY))
    return system, env


def refuse(root, name, *, pin_contents=None, expected):
    system, env = project(root, name, pin_contents=pin_contents)
    result = run([str(system / "bin/install-remote-collection")], env=env, check=False)
    output = result.stdout + result.stderr
    assert result.returncode != 0 and expected in output, output
    assert not (system / ".ansible/collections").exists()


source_head_before = git(SOURCE, "rev-parse", "HEAD")
source_status_before = git(SOURCE, "status", "--porcelain", "--untracked-files=all")
with tempfile.TemporaryDirectory(prefix="agent-remote-bootstrap.", dir=CACHE) as temporary:
    root = Path(temporary)
    SOURCE_COPY = root / "source"
    run(["git", "clone", "--quiet", "--no-hardlinks", "--no-checkout", str(SOURCE), str(SOURCE_COPY)])
    parent = git(SOURCE_COPY, "rev-parse", "--verify", f"{PIN}^")
    run(["git", "-C", str(SOURCE_COPY), "checkout", "--quiet", "--detach", parent])
    assert git(SOURCE_COPY, "rev-parse", "HEAD") != PIN

    mutable = SOURCE_COPY / "ansible/roles/agent/tasks/main.yaml"
    mutable.write_bytes(mutable.read_bytes() + b"\n# mutable checkout probe\n")
    untracked = SOURCE_COPY / "ansible/bootstrap-untracked-probe"
    untracked.write_text("untracked checkout content\n")
    ignored = SOURCE_COPY / "ansible/roles/agent/files/bootstrap-ignored-probe"
    exclude = SOURCE_COPY / ".git/info/exclude"
    exclude.write_text(exclude.read_text() + "/ansible/roles/agent/files/bootstrap-ignored-probe\n")
    ignored.write_text("ignored checkout content\n")
    run(["git", "-C", str(SOURCE_COPY), "check-ignore", "-q",
         "ansible/roles/agent/files/bootstrap-ignored-probe"])
    assert git(SOURCE_COPY, "status", "--porcelain", "--untracked-files=all")

    system, env = project(root, "pinned")
    result = run([str(system / "bin/install-remote-collection")], env=env)
    assert f"installed aiagent.remote from revision {PIN}" in result.stdout
    assert (system / ".ansible/collection-revision").read_text().strip() == PIN
    collection = system / ".ansible/collections/ansible_collections/aiagent/remote"
    metadata = yaml.safe_load(git_bytes(SOURCE_COPY, "show", f"{PIN}:ansible/galaxy.yml"))
    collection_info = json.loads((collection / "MANIFEST.json").read_text())["collection_info"]
    for key in ("namespace", "name", "version", "authors", "readme", "description", "tags"):
        assert collection_info[key] == metadata[key], key
    file_list = json.loads((collection / "FILES.json").read_text())["files"]
    packaged_files = {entry["name"] for entry in file_list if entry["ftype"] == "file"}
    tracked_files = set(git(SOURCE_COPY, "ls-tree", "-r", "--name-only", PIN, "ansible").splitlines())
    tracked_files = {name.removeprefix("ansible/") for name in tracked_files}
    assert packaged_files == tracked_files - {"galaxy.yml"}, (packaged_files ^ (tracked_files - {"galaxy.yml"}))
    for entry in file_list:
        if entry["ftype"] != "file":
            continue
        name = entry["name"]
        expected = git_bytes(SOURCE_COPY, "show", f"{PIN}:ansible/{name}")
        installed = (collection / name).read_bytes()
        assert installed == expected, name
        assert hashlib.sha256(installed).hexdigest() == entry["chksum_sha256"], name
    assert not (collection / "bootstrap-untracked-probe").exists()
    assert not (collection / "roles/agent/files/bootstrap-ignored-probe").exists()
    assert b"mutable checkout probe" not in (collection / "roles/agent/tasks/main.yaml").read_bytes()
    assert mutable.read_bytes().endswith(b"# mutable checkout probe\n")
    assert git(SOURCE_COPY, "rev-parse", "HEAD") == parent

    (root / "ansible-tmp").mkdir()
    artifact_env = dict(
        os.environ,
        AIAGENT_REMOTE_COLLECTION_ROOT=str(collection),
        ANSIBLE_COLLECTIONS_PATH=str(system / ".ansible/collections"),
        TMPDIR=str(root / "ansible-tmp"),
    )
    run(["python3", str(SYSTEM / "tests/gak/compose-consumer-check.py")], env=artifact_env)
    run(["python3", str(SYSTEM / "tests/gak/list-render.py")], env=artifact_env)

    refuse(root, "missing-pin", pin_contents=None, expected="collection-pin is missing")
    refuse(root, "invalid-pin", pin_contents="not-a-commit\n", expected="one full Git commit ID")
    refuse(root, "missing-object", pin_contents="0" * 40 + "\n",
           expected="pinned collection commit is not present")

assert git(SOURCE, "rev-parse", "HEAD") == source_head_before
assert git(SOURCE, "status", "--porcelain", "--untracked-files=all") == source_status_before

print("collection bootstrap: exact pinned tree installed with divergent HEAD and dirty, untracked, and ignored source files")
print("collection bootstrap: current consumer check and media render passed from the installed artifact")
print("collection bootstrap: missing, malformed, and unavailable commit pins were refused")
