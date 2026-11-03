#!/usr/bin/env python3
"""Check the shipped runtime no longer depends on the old launcher."""
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class NoRofi(unittest.TestCase):
    def test_runtime_has_no_rofi_references(self):
        pattern = re.compile(r"\brofi\b|rice-rofi", re.IGNORECASE)
        roots = [ROOT / name for name in ("bin", "config", "install", "lua", "quickshell", "settings")]
        files = [ROOT / "install.sh", ROOT / "sync.sh"]
        for root in roots:
            files.extend(p for p in root.rglob("*") if p.is_file())
        for path in files:
            if path.is_symlink() or path.stat().st_size > 1_000_000:
                continue
            text = path.read_text(errors="ignore")
            self.assertIsNone(pattern.search(text), str(path.relative_to(ROOT)))
            self.assertNotIn("rofi", path.name.lower(), str(path.relative_to(ROOT)))

    def test_session_commands_do_not_execute_for_real(self):
        module = runpy.run_path(str(ROOT / "bin/rice-services"))
        calls = []
        def fake_run(args, *unused):
            calls.append(args)
        with patch.dict(module["session"].__globals__, {"run": fake_run}):
            for name in ("logout", "reboot", "poweroff"):
                module["session"](name)
        self.assertEqual(calls, [["swaync-client", "-cp"], ["hyprctl", "dispatch", "exit"],
                                 ["swaync-client", "-cp"], ["systemctl", "reboot"],
                                 ["swaync-client", "-cp"], ["systemctl", "poweroff"]])

    def test_wallpaper_fails_cleanly_without_picker(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            result = subprocess.run(["/bin/bash", str(ROOT / "bin/rice-wallpaper")],
                                    env={"HOME": tmp, "PATH": tmp}, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("hyprquickpaper or waypaper is required", result.stderr)

    def test_wallpaper_picker_paths(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            home = Path(tmp)
            tools = home / "tools"
            tools.mkdir()
            for name, body in (("pgrep", "exit 1"), ("qs", 'printf "qs %s\\n" "$*"'),
                               ("waypaper", 'printf "waypaper\\n"')):
                stub = tools / name
                stub.write_text("#!/bin/sh\n" + body + "\n")
                stub.chmod(0o755)
            env = {"HOME": tmp, "PATH": str(tools)}
            command = ["/bin/bash", str(ROOT / "bin/rice-wallpaper")]
            result = subprocess.run(command, env=env, text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), "waypaper")
            picker = home / ".config/quickshell/hyprquickpaper/shell.qml"
            picker.parent.mkdir(parents=True)
            picker.touch()
            result = subprocess.run(command, env=env, text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout.strip(), f"qs -n -p {picker.parent}")


if __name__ == "__main__":
    unittest.main()
