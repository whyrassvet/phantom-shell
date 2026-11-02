#!/usr/bin/env python3
"""Exercise Hyprland boolean state and toggle commands without a real session."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HyprSettingsBooleans(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="hypr-set-test-", dir="/tmp/opencode")
        self.addCleanup(self.tmp.cleanup)
        home = Path(self.tmp.name)
        (home / ".config/hypr").mkdir(parents=True)
        tools = home / "bin"
        tools.mkdir()
        self.state = home / "hypr-state.json"
        self.state.write_text(json.dumps({"decoration:blur:enabled": True, "decoration:blur:xray": False,
                                          "general:resize_on_border": True}))
        hyprctl = tools / "hyprctl"
        hyprctl.write_text('''#!/usr/bin/env python3
import json, os, re, sys
path = os.environ["FAKE_HYPR_STATE"]
state = json.load(open(path))
if sys.argv[1:3] == ["-j", "getoption"]:
    key = sys.argv[3]
    if key in state:
        value = state[key]
        # Test both the current boolean schema and older integer responses.
        print(json.dumps({"int" if key == "general:resize_on_border" else "bool": int(value) if key == "general:resize_on_border" else value}))
    else:
        print("{}")
elif sys.argv[1] == "eval":
    pairs = re.findall(r"(\\w+)\\s*=\\s*(?:\\{\\s*)?(true|false)?", sys.argv[2])
    key = ":".join(k for k, _ in pairs)
    state[key] = pairs[-1][1] == "true"
    json.dump(state, open(path, "w"))
    print("ok")
''')
        hyprctl.chmod(0o755)
        self.env = dict(os.environ, HOME=str(home), FAKE_HYPR_STATE=str(self.state), PATH=str(tools) + os.pathsep + os.environ["PATH"])

    def run_tool(self, *args):
        return subprocess.run([str(ROOT / "bin/hypr-set"), *args], env=self.env, check=True, text=True, capture_output=True).stdout

    def test_boolean_state_and_toggling(self):
        opts = json.loads(self.run_tool("state"))["opts"]
        self.assertIs(opts["decoration.blur.enabled"], True)
        self.assertIs(opts["decoration.blur.xray"], False)
        self.assertIs(opts["general.resize_on_border"], True)
        for key in ("decoration.blur.enabled", "decoration.blur.xray"):
            for value in ("false", "true", "false"):
                self.run_tool("set", key, value)
                self.assertIs(json.loads(self.run_tool("state"))["opts"][key], value == "true")
                self.assertIs(json.loads(self.state.read_text())[key.replace(".", ":")], value == "true")


if __name__ == "__main__":
    unittest.main()
