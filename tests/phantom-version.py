#!/usr/bin/env python3
"""Version ordering and updater checks without a live installation or network."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / "bin"))
from phantom_version import clean, key

ordered = ["0.1.0", "0.1.1-alpha", "0.1.1-alpha.1", "0.1.1-alpha.2", "0.1.1-alpha.10", "0.1.1-beta", "0.1.1", "0.1.2-alpha", "0.2.0-alpha", "0.2.0", "0.2.1-alpha", "0.2.1", "0.2.2-alpha", "0.2.2", "0.3.0-beta", "0.3.0"]
assert all(key(a) < key(b) for a, b in zip(ordered, ordered[1:]))
assert key("v0.1.1+build.5") == key("0.1.1")
assert key("2.02") < key("2.97")
assert clean("0.1.1-alpha.01") == "" and clean("0.1.01") == "" and clean("invalid") == ""
assert subprocess.run([sys.executable, str(root / "bin/phantom_version.py"), "0.1.1", "0.1.1-alpha"]).returncode == 0
assert subprocess.run([sys.executable, str(root / "bin/phantom_version.py"), "0.1.1-alpha", "0.1.1"]).returncode == 1

with tempfile.TemporaryDirectory(prefix="phantom-version-", dir="/tmp/opencode") as tmp:
    home = Path(tmp)
    rice = home / ".config/rice"
    rice.mkdir(parents=True)
    repo = home / "phantom-shell"
    repo.mkdir()
    (repo / "install.sh").write_text("")
    (repo / "VERSION").write_text("0.1.1-alpha\n")
    (repo / "CHANGELOG.md").write_text("## v0.1.1-alpha\n- Example change\n")
    (rice / "repo").write_text(str(repo))
    (rice / "version").write_text("0.1.0\n")
    env = {**os.environ, "HOME": str(home)}
    cmd = [sys.executable, str(root / "bin/rice-update"), "check", "--json", "--offline"]
    state = json.loads(subprocess.check_output(cmd, env=env))
    assert state["installed"] == "0.1.0" and state["latest"] == "0.1.1-alpha" and state["update"] and state["news"] == ["Example change"]
    (rice / "version").write_text("0.1.1-alpha\n")
    state = json.loads(subprocess.check_output(cmd, env=env))
    assert not state["update"] and state["latest"] == "0.1.1-alpha"
print("Version and offline update checks passed")
