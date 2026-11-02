#!/usr/bin/env python3
"""Check distro selection and helper PATH without touching the current system."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DistroSupport(unittest.TestCase):
    def test_distribution_families(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            release = Path(tmp) / "os-release"
            for distro, like, expected in (("cachyos", "arch", "arch"), ("fedora", "", "fedora"),
                                            ("nixos", "", "other"), ("unknown", "", "other")):
                with self.subTest(distro=distro):
                    release.write_text(f'ID="{distro}"\nNAME="test"\nID_LIKE="{like}"\n')
                    env = dict(os.environ, OS_RELEASE=str(release), OSTREE_BOOTED=str(Path(tmp) / "absent"))
                    result = subprocess.run(["bash", "-c", 'source "$1"; printf "%s" "$FAMILY"', "_",
                                             str(ROOT / "install/lib/distro.sh")],
                                            env=env, text=True, capture_output=True, check=True)
                    self.assertEqual(result.stdout, expected)

    def test_rice_run_uses_standard_path(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            home = Path(tmp)
            bindir = home / ".local/bin"
            bindir.mkdir(parents=True)
            probe = bindir / "probe"
            probe.write_text('#!/bin/sh\nprintf "%s\\n" "$PATH" > "$HOME/result"\n')
            probe.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH="/usr/bin:/bin")
            subprocess.run([str(ROOT / "bin/rice-run"), "probe"], env=env, check=True)
            path = (home / "result").read_text().strip().split(":")
            self.assertEqual(path[:4], [str(bindir), "/usr/local/bin", "/usr/bin", "/bin"])
            self.assertFalse(any("nix" in part for part in path))


if __name__ == "__main__":
    unittest.main()
