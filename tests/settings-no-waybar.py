#!/usr/bin/env python3
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SettingsWithoutWaybar(unittest.TestCase):
    def test_no_rofi_page_and_navigation_indices(self):
        shell = (ROOT / "quickshell/rice-settings/shell.qml").read_text()
        home = (ROOT / "quickshell/rice-settings/HomePage.qml").read_text()
        self.assertNotIn("Rofi", shell)
        self.assertNotIn("Rofi", home)
        self.assertFalse((ROOT / "quickshell/rice-settings/RofiPage.qml").exists())
        page_block = shell.split("readonly property var pages: [", 1)[1].split("\n    ]", 1)[0]
        pages = re.findall(r'name: "([^"]+)"', page_block)
        slots = dict((int(idx), component) for idx, component in re.findall(
            r'PageSlot \{\s*idx: (\d+); cur: win\.page;?\s+(\w+)', shell))
        expected = {0: "HomePage", 1: "SoundsPage", 2: "PhantomBarPage", 4: "HyprlandPage",
                    5: "DashboardPage", 6: "ThemePage", 7: "CursorsPage", 8: "NotificationsPage",
                    9: "IdlePage", 10: "DesktopPage", 11: "HotCornersPage", 12: "InterfacePage",
                    13: "ServicesPage", 14: "Flickable", 15: "UpdatePage"}
        self.assertEqual(slots, expected)
        self.assertEqual(len(pages), 16)
        for label, index in (("Theme", 6), ("Notifications", 8), ("Lock screen", 9), ("Bar", 2)):
            self.assertRegex(home, r't: "' + re.escape(label) + r'", d: "[^"]+", p: ' + str(index) + r'\s*}')
        self.assertEqual([pages[i] for i in (6, 8, 9, 14)], ["Theme", "Notifications", "Idle & Lockscreen", "Monitors"])

    def test_navigation_has_placeholder_and_no_waybar_controls(self):
        shell = (ROOT / "quickshell/rice-settings/shell.qml").read_text()
        home = (ROOT / "quickshell/rice-settings/HomePage.qml").read_text()
        self.assertIn('name: "Bar"', shell)
        self.assertIn('PhantomBarPage {', shell)
        self.assertIn('name: "Bar layout", icon: "\\uf0db", hidden: true', shell)
        for text in (shell, home):
            for old in ('waybar-reload', 'WaybarPage {', 'BarLayoutPage {', 'page.ctl.run(["transparency"'):
                self.assertNotIn(old, text)

    def test_matugen_does_not_restart_waybar(self):
        config = tomllib.loads((ROOT / "config/matugen/config.toml").read_text())
        self.assertNotIn("post_hook", config["templates"]["waybar"])
        self.assertIn("output_path", config["templates"]["waybar"])

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
