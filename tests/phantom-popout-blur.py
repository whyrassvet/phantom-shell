#!/usr/bin/env python3
"""Keep the bar and popout Hyprland blur rules in sync."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PopoutBlurRules(unittest.TestCase):
    def test_bar_and_popout_match(self):
        config = (ROOT / "config/hypr/hyprland.lua").read_text()
        def rule(name):
            match = re.search(r'hl\.layer_rule\(\{\s*name\s*=\s*"' + re.escape(name) + r'"(.*?)\n\}\)', config, re.S)
            self.assertIsNotNone(match, name)
            return match.group(1)
        bar = rule("caelestia-bar-blur")
        popout = rule("caelestia-popouts-blur")
        self.assertIn('namespace = "caelestia-bar"', bar)
        self.assertIn('namespace = "caelestia-popouts"', popout)
        for setting in ("blur = true", "ignore_alpha = 0.1"):
            self.assertIn(setting, bar)
            self.assertIn(setting, popout)


if __name__ == "__main__":
    unittest.main()
