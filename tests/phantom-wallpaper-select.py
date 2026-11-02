#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("wallpaper_select", str(ROOT / "bin/phantom-wallpaper-select"))
spec = importlib.util.spec_from_loader(loader.name, loader)
selector = importlib.util.module_from_spec(spec)
loader.exec_module(selector)


class SelectionTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="phantom-select-test-", dir="/tmp/opencode")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name)
        (self.path / "nested").mkdir()
        self.large = self.path / "nested/large.png"
        self.other = self.path / "other.jpg"
        self.small = self.path / "small.png"
        Image.new("RGB", (100, 80)).save(self.large)
        Image.new("RGB", (100, 80)).save(self.other)
        Image.new("RGB", (10, 10)).save(self.small)
        (self.path / "broken.png").write_text("not an image")

    def test_size_and_current(self):
        self.assertEqual(selector.select(self.path, self.large, (100, 80)), self.other)

    def test_only_current_remains_valid(self):
        self.other.unlink()
        self.assertEqual(selector.select(self.path, self.large, (100, 80)), self.large)

    def test_no_candidates(self):
        with self.assertRaisesRegex(ValueError, "No valid wallpapers"):
            selector.select(self.path, size=(1000, 1000))

    def test_monitor_size_and_invalid_response(self):
        class Result:
            stdout = json.dumps([{"width": 1920, "height": 1080}, {"width": 2560, "height": 1440}])
        with patch.object(selector.subprocess, "run", return_value=Result()):
            self.assertEqual(selector.minimum_monitor_size(), (1920, 1080))
            Result.stdout = "[]"
            with self.assertRaisesRegex(ValueError, "No monitors"):
                selector.minimum_monitor_size()


if __name__ == "__main__":
    unittest.main()
