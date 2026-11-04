#!/usr/bin/env python3
"""Old corner settings must not affect the fixed hot corner."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
script = ROOT / "bin/rice-hotcorner"
with tempfile.TemporaryDirectory(prefix="phantom-fixed-corner-", dir="/tmp/opencode") as tmp:
    home = Path(tmp)
    config = home / ".config/rice/hotcorner.json"
    config.parent.mkdir(parents=True)
    config.write_text(json.dumps({"corner": "top-left", "enabled": True, "delay": 75}))
    env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config"), "XDG_CACHE_HOME": str(home / ".cache")}
    result = subprocess.run([script, "config"], env=env, text=True, capture_output=True, check=True)
    cfg = json.loads(result.stdout)
    assert "corner" not in cfg and cfg["enabled"] and cfg["delay"] == 75
    result = subprocess.run([script, "set", "corner", "top-left"], env=env, text=True, capture_output=True)
    assert result.returncode != 0
    subprocess.run([script, "set", "delay", "100"], env=env, check=True)
    saved = json.loads(config.read_text())
    assert "corner" not in saved and saved["delay"] == 100
print("Fixed hot corner ignores and removes legacy corner settings.")
