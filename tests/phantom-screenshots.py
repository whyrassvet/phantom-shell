#!/usr/bin/env python3
"""Exercise screenshot orchestration without touching the real desktop."""
import os
from pathlib import Path
import runpy
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp, patch.dict(os.environ, {"HOME": tmp}):
    module = runpy.run_path(str(ROOT / "bin/rice-hotcorner"), run_name="screenshot_test")
    shot = module["shot_take"]
    state = shot.__globals__
    state["SHOT_DIR"] = tmp
    calls = []
    notices = []

    class Freeze:
        def __init__(self, cmd, **kwargs):
            self.alive = True
            calls.append(cmd)

        def poll(self):
            return None if self.alive else 0

        def terminate(self):
            calls.append("terminate")
            self.alive = False

        def wait(self, timeout=None):
            return 0

    def run(cmd, timeout=3):
        calls.append(cmd)
        if cmd[0] == "slurp":
            return 0, "10,20 30x40\n"
        return 0, ""

    state["q"] = run
    state["notify"] = lambda *args: notices.append(args)
    state["load"] = lambda: {"clipboard": False, "shot_overlay": "dark"}
    with patch.object(state["shutil"], "which", return_value="/fake"), \
         patch.object(state["subprocess"], "Popen", Freeze), patch.object(state["time"], "sleep"):
        shot("region")
        assert calls[0] == ["hyprpicker", "-r", "-z", "-d"]
        assert calls[1] == ["slurp", "-b", "#00000080"]
        assert calls[2][:4] == ["grim", "-l", "1", "-g"] and calls[2][4] == "10,20 30x40"
        assert calls[3] == "terminate" and notices[-1][0] == "Screenshot saved"
        calls.clear()
        state["load"] = lambda: {"clipboard": False, "shot_overlay": "light"}
        shot("region")
        assert calls[1] == ["slurp", "-b", "#ffffff80"]
        calls.clear()
        shot("full")
        assert calls[0][:3] == ["grim", "-l", "1"] and len(calls) == 1
        calls.clear()
        state["q"] = lambda cmd, timeout=3: (1, "") if cmd[0] == "slurp" else (0, "")
        shot("region")
        assert calls[-1] == "terminate"

assert 'hl.unbind("SUPER + SHIFT + S")' in (ROOT / "lua/rice-keys.lua").read_text()
assert 'start swaync.service' not in (ROOT / "config/hypr/hyprland.lua").read_text()
print("Screenshot orchestration, overlay modes, cancellation, and bindings passed.")
