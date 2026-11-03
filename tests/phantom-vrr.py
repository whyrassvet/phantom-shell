#!/usr/bin/env python3
"""Verify VRR persistence and failure handling without changing the live compositor."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="phantom-vrr-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    (p / "bin").mkdir()
    fake = p / "bin/hyprctl"
    fake.write_text('#!/bin/sh\n[ "$FAIL_VRR" = 1 ] && { echo error >&2; exit 1; }\nprintf "%s\\n" "$@" >> "$HOME/calls"\n')
    fake.chmod(0o755)
    env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(p / "config"), PATH=str(p / "bin") + ":" + os.environ["PATH"])
    cmd = [str(root / "bin/hypr-set"), "vrr-set"]
    override = p / "config/phantom-shell/hyprland-vrr.lua"
    for value in ("1", "0"):
        subprocess.run(cmd + [value], env=env, check=True)
        assert "vrr = " + value in override.read_text()
        assert "vrr = " + value in (p / "calls").read_text()
    old = override.read_text()
    assert subprocess.run(cmd + ["1"], env=dict(env, FAIL_VRR="1")).returncode != 0
    assert override.read_text() == old
    assert subprocess.run(cmd + ["3"], env=env).returncode != 0
    assert override.read_text() == old
    assert not list(override.parent.glob('.hyprland-vrr-*'))

config = (root / "config/hypr/hyprland.lua").read_text()
assert config.index('loadPhantomFile("hyprland-user.lua")') < config.index('loadPhantomFile("hyprland-vrr.lua")')
print("VRR persistence, validation, failure handling and load order OK")
