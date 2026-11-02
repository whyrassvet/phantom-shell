#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SettingsWithoutWaybar(unittest.TestCase):
    def test_navigation_has_placeholder_and_no_waybar_controls(self):
        shell = (ROOT / "quickshell/rice-settings/shell.qml").read_text()
        home = (ROOT / "quickshell/rice-settings/HomePage.qml").read_text()
        self.assertIn('name: "Bar"', shell)
        self.assertIn('text: "Work in progress"', shell)
        self.assertIn('name: "Bar layout", icon: "\\uf0db", hidden: true', shell)
        for text in (shell, home):
            for old in ('waybar-reload', 'WaybarPage {', 'BarLayoutPage {', 'page.ctl.run(["transparency"'):
                self.assertNotIn(old, text)

    def test_matugen_does_not_restart_waybar(self):
        config = tomllib.loads((ROOT / "config/matugen/config.toml").read_text())
        self.assertNotIn("post_hook", config["templates"]["waybar"])
        self.assertIn("phantom-bar", config["templates"])

    def test_font_changes_do_not_launch_waybar(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            tools = home / "tools"
            tools.mkdir()
            fc = tools / "fc-list"
            fc.write_text("#!/bin/sh\necho 'Test Font'\n")
            fc.chmod(0o755)
            bindir = home / ".local/bin"
            bindir.mkdir(parents=True)
            for name in ("waybar-set", "waybar-reload"):
                stub = bindir / name
                stub.write_text('#!/bin/sh\ntouch "$HOME/waybar-called"\n')
                stub.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH=str(tools) + os.pathsep + os.environ["PATH"])
            for args in (("set", "main", "Test Font"), ("set", "icons", "Test Font"), ("reset",)):
                subprocess.run([str(ROOT / "bin/font-set"), *args], env=env, check=True, capture_output=True)
            self.assertFalse((home / "waybar-called").exists())


if __name__ == "__main__":
    unittest.main()
