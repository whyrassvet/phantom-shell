#!/usr/bin/env python3
"""Verify wallpaper apply failures without touching the real session or themes."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "quickshell/hyprquickpaper/commands.sh"


class WallpaperApplyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="wallpaper-errors-", dir="/tmp/opencode")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.image = self.home / "test image.png"
        self.image.write_bytes(b"fake image")
        self.log = self.home / "calls"
        for name in ("awww", "convert", "matugen"):
            p = self.bin / name
            p.write_text('#!/bin/sh\nprintf "%s\\n" "$(basename "$0")" >> "$LOG"\n'
                         'if [ "$FAIL" = "$(basename "$0")" ]; then exit 9; fi\n'
                         'if [ "$(basename "$0")" = convert ]; then echo "${SAT:-50}"; fi\n'
                         'if [ "$(basename "$0")" = matugen ]; then printf "%s\\n" "$@" >> "$LOG"; fi\n')
            p.chmod(0o755)
        colors = self.home / ".local/bin/rice-colors"
        colors.parent.mkdir(parents=True)
        colors.write_text('#!/bin/sh\n[ "$1" != scheme ] || exit 1\nexit 0\n')
        colors.chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), PATH=f"{self.bin}:/usr/bin:/bin",
                        LOG=str(self.log), FAIL="")
        self.current = self.home / ".cache/hyprquickpaper-current"

    def run_apply(self, fail=""):
        return subprocess.run(["bash", str(SCRIPT), str(self.image)],
                              env=dict(self.env, FAIL=fail), capture_output=True, text=True)

    def test_success_records_current_wallpaper(self):
        result = self.run_apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.current.read_text().strip(), str(self.image))
        self.assertIn("matugen", self.log.read_text())

    def test_errors_do_not_report_success_or_change_current(self):
        for failing in ("awww", "convert", "matugen"):
            with self.subTest(failing=failing):
                self.current.parent.mkdir(parents=True, exist_ok=True)
                self.current.write_text("previous\n")
                self.log.write_text("")
                result = self.run_apply(failing)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.current.read_text(), "previous\n")
                if failing == "awww":
                    self.assertNotIn("matugen", self.log.read_text())

    def test_unknown_scheme_keeps_existing_fallback(self):
        config = self.home / ".config/rice/color-mode"
        config.parent.mkdir(parents=True)
        config.write_text("unknown\n")
        self.assertEqual(self.run_apply().returncode, 0)

    def test_monochrome_and_explicit_navy(self):
        config = self.home / ".config/rice/color-mode"
        config.parent.mkdir(parents=True)
        for mode, saturation, expected in (("auto", "2.44", "scheme-monochrome"),
                                            ("grey", "50", "scheme-monochrome"),
                                            ("navy", "2.44", "#1a2a5e"),
                                            ("auto", "50", "--source-color-index")):
            with self.subTest(mode=mode, saturation=saturation):
                config.write_text(mode + "\n")
                self.log.write_text("")
                self.env["SAT"] = saturation
                result = self.run_apply()
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.log.read_text()
                self.assertIn(expected, calls)
                if mode == "auto":
                    self.assertNotIn("#1a2a5e", calls)


if __name__ == "__main__":
    unittest.main()
