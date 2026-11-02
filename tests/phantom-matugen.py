#!/usr/bin/env python3
"""Render the bar template with Matugen without the user's config or hooks."""
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "config/matugen/templates/phantom-bar.json"
IMAGE = ROOT / "quickshell/caelestia-bar/assets/wallpaper.webp"


class MatugenTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="phantom-matugen-test-", dir="/tmp/opencode")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        self.output = self.path / "palette.json"
        self.config = self.path / "matugen.toml"
        self.config.write_text(
            "[config]\n[templates.phantom-bar]\n"
            f"input_path = {json.dumps(str(TEMPLATE))}\n"
            f"output_path = {json.dumps(str(self.output))}\n"
        )
        self.env = dict(os.environ, HOME=str(self.path), XDG_CONFIG_HOME=str(self.path / "config"),
                        XDG_CACHE_HOME=str(self.path / "cache"), XDG_DATA_HOME=str(self.path / "data"),
                        XDG_STATE_HOME=str(self.path / "state"))

    def render(self, *args):
        subprocess.run(["matugen", *args, "--config", str(self.config), "--quiet"],
                       env=self.env, check=True, capture_output=True, text=True)
        palette = json.loads(self.output.read_text())
        self.assertEqual(palette["name"], "shadows-matugen")
        self.assertGreaterEqual(len(palette["colours"]), 35)
        for colour in palette["colours"].values():
            self.assertRegex(colour, r"^#[0-9a-fA-F]{6}$")
        return palette

    def test_image_and_named_theme(self):
        image = self.render("image", str(IMAGE), "--source-color-index", "0", "--mode", "dark")
        self.assertEqual(image["mode"], "dark")
        named = self.render("color", "hex", "#0a84c8", "--type", "scheme-tonal-spot", "--mode", "dark")
        self.assertEqual(named["mode"], "dark")
        self.assertNotEqual(image["colours"]["primary"], named["colours"]["primary"])

    def test_light_mode(self):
        self.assertEqual(self.render("color", "hex", "#0a84c8", "--mode", "light")["mode"], "light")


if __name__ == "__main__":
    unittest.main()
