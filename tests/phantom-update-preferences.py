#!/usr/bin/env python3
"""Exercise update channels, notification filters and release installation in isolation."""
import importlib.machinery
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "bin"))
update = importlib.machinery.SourceFileLoader("phantom_update", str(ROOT / "bin/rice-update")).load_module()


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir="/tmp/opencode")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "user.email", "test@example.org")
        self.git("config", "user.name", "Test")
        self.git("remote", "add", "origin", str(self.repo))
        self.saved = {key: getattr(update, key) for key in ("DIR", "CACHE", "STATE", "NOTIFIED", "PREFERENCES", "INSTALLED")}
        self.addCleanup(lambda: [setattr(update, k, v) for k, v in self.saved.items()])
        update.DIR = str(self.base / "config")
        update.CACHE = str(self.base / "cache")
        update.STATE = update.CACHE + "/update.json"
        update.NOTIFIED = update.CACHE + "/notified"
        update.PREFERENCES = update.DIR + "/update-settings.json"
        update.INSTALLED = update.DIR + "/version"
        Path(update.DIR).mkdir()
        Path(update.CACHE).mkdir()
        Path(update.INSTALLED).write_text("0.4.0-beta\n")
        self.repo_patch = patch.object(update, "repo", return_value=str(self.repo))
        self.repo_patch.start()
        self.addCleanup(self.repo_patch.stop)
        self.release("0.3.0")
        self.release("0.4.0-beta", annotated=True)
        self.release("0.5.0-alpha")

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def release(self, version, annotated=False):
        (self.repo / "VERSION").write_text(version + "\n")
        (self.repo / "CHANGELOG.md").write_text("## " + version + "\n- Test release\n")
        (self.repo / "install.sh").write_text('#!/bin/sh\nprintf "%s\\n%s\\n" "$PHANTOM_UPDATE_REPO" "$*" > "' + str(self.base / "installed") + '"\npwd > "' + str(self.base / "config/repo") + '"\n')
        (self.repo / "install.sh").chmod(0o755)
        self.git("add", ".")
        self.git("commit", "-qm", version)
        self.git("tag", *(["-a", "v" + version, "-m", version] if annotated else ["v" + version]))

    def test_channels_and_real_install_target(self):
        self.assertEqual(update.check()["latest"], "0.4.0-beta")
        update.set_preference("beta", "off")
        st = update.check()
        self.assertEqual(st["latest"], "0.3.0")
        self.assertFalse(st["update"])
        self.release("0.4.0")
        self.release("0.5.0-beta", annotated=True)
        self.assertEqual(update.check()["latest"], "0.4.0")
        before = self.git("rev-parse", "HEAD").stdout
        with patch("builtins.input", return_value=""), self.assertRaises(SystemExit) as exited:
            update.run([])
        self.assertEqual(exited.exception.code, 0)
        self.assertEqual((self.base / "installed").read_text().splitlines(), [str(self.repo), "--update --pulled"])
        self.assertEqual(Path(update.DIR, "repo").read_text().strip(), str(self.repo))
        self.assertEqual(self.git("rev-parse", "HEAD").stdout, before)
        update.set_preference("beta", "on")
        self.assertEqual(update.check()["latest"], "0.5.0-beta")
        self.assertEqual(update.check(offline=True)["latest"], "0.5.0-beta")

    def test_notification_filters_and_persistence(self):
        self.assertEqual(update.preferences(), update.DEFAULTS)
        calls = []
        with patch.object(update, "start_watch"), patch.object(update, "notify_bg", side_effect=lambda st: calls.append(st["latest"])):
            update.set_preference("notifications", "on")
            update.set_preference("major_only", "on")
            def send(installed, latest):
                update.maybe_notify({"installed": installed, "latest": latest, "update": True})
            send("0.4.0", "0.4.1")
            send("0.4.2", "0.5.1")
            send("0.4.2", "0.5.2")
            self.assertEqual(calls, ["0.5.1"])
            update.set_preference("major_only", "off")
            send("0.4.0", "0.4.1")
            send("0.4.0", "0.4.1")
            update.set_preference("beta", "off")
            send("0.4.0", "0.5.0-beta")
            update.set_preference("notifications", "off")
            send("0.4.0", "0.5.0")
            self.assertEqual(calls, ["0.5.1", "0.4.1"])
        self.assertEqual(json.loads(Path(update.PREFERENCES).read_text()), {"notifications": False, "major_only": False, "beta": False})
        with self.assertRaises(ValueError):
            update.set_preference("beta", "invalid")

    def test_empty_stable_channel_and_invalid_tag(self):
        self.git("tag", "-d", "v0.3.0")
        update.set_preference("beta", "off")
        self.assertIn("No releases", update.check()["error"])
        self.assertFalse(update.release_tag("v1.0.0-alpha", True))
        self.assertFalse(update.release_tag("v1.0.0-beta", False))

    def test_watcher_is_opt_in(self):
        with patch.object(update.subprocess, "Popen") as popen:
            update.start_watch()
            popen.assert_not_called()
            update.set_preference("notifications", "on")
            self.assertEqual(popen.call_count, 1)
            self.assertEqual(popen.call_args.args[0][-1], "watch")
            update.set_preference("notifications", "off")
            update.start_watch()
            self.assertEqual(popen.call_count, 1)

    def test_history_uses_installed_tag_and_checked_release(self):
        self.assertEqual(update.installed_history()[0]["version"], "0.4.0-beta")
        entries = update.changelog_entries("# Changelog\n## v0.5.0\n- First\n* Second\n## v0.4.0\n- Older\n")
        self.assertEqual(entries, [{"version": "v0.5.0", "lines": ["First", "Second"]},
                                   {"version": "v0.4.0", "lines": ["Older"]}])
        self.assertEqual(update.check()["history"][0]["version"], "0.4.0-beta")


if __name__ == "__main__":
    unittest.main()
