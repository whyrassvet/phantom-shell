#!/usr/bin/env python3
"""Keep launcher blur and transparency behavior aligned with the bar."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LauncherBlurRules(unittest.TestCase):
    def test_launcher_matches_bar(self):
        config = (ROOT / "config/hypr/hyprland.lua").read_text()
        def rule(name):
            match = re.search(r'hl\.layer_rule\(\{\s*name\s*=\s*"' + re.escape(name) + r'"(.*?)\n\}\)', config, re.S)
            self.assertIsNotNone(match, name)
            return match.group(1)
        bar, launcher = rule("caelestia-bar-blur"), rule("phantom-launcher-blur")
        self.assertIn('namespace = "phantom-app-launcher"', launcher)
        for setting in ("blur = true", "ignore_alpha = 0.1"):
            self.assertIn(setting, bar)
            self.assertIn(setting, launcher)
        colours = (ROOT / "quickshell/caelestia-bar/services/Colours.qml").read_text()
        self.assertEqual(colours.count("(caelestia-(bar|popouts)|phantom-app-launcher)"), 2)


if __name__ == "__main__":
    unittest.main()
