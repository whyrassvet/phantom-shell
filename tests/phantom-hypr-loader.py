#!/usr/bin/env python3
"""Exercise the actual Lua loader without starting or reloading Hyprland."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "config/hypr/hyprland.lua"


class LoaderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="phantom-hypr-loader-", dir="/tmp/opencode")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.user_dir = self.path / "phantom-shell"
        self.user_dir.mkdir()
        source = CONFIG.read_text()
        start = source.index("local phantomConfigHome =")
        end = source.index("\n------------------\n---- MONITORS", start)
        self.loader = source[start:end]

    def execute(self, suffix):
        env = dict(os.environ, XDG_CONFIG_HOME=str(self.path))
        return subprocess.run(["lua", "-"], input=self.loader + "\n" + suffix,
                              capture_output=True, text=True, env=env)

    def test_missing_files_and_vars(self):
        self.assertEqual(self.execute('assert(next(phantomVars) == nil)').returncode, 0)
        (self.user_dir / "hyprland-vars.lua").write_text('return { terminal = "example" }\n')
        (self.user_dir / "hyprland-user.lua").write_text('loaded = "yes"\n')
        result = self.execute('assert(phantomVars.terminal == "example"); loadPhantomFile("hyprland-user.lua"); assert(loaded == "yes")')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_vars_are_not_silently_ignored(self):
        for value in ('"invalid"', 'false'):
            (self.user_dir / "hyprland-vars.lua").write_text(f'return {value}\n')
            result = self.execute('')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("must return a table", result.stderr)


if __name__ == "__main__":
    unittest.main()
