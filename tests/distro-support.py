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
            for distro, like, expected in (("arch", "", "arch"), ("cachyos", "arch", "arch"),
                                            ("endeavouros", "arch", "arch"), ("garuda", "arch", "arch"),
                                            ("manjaro", "arch", "arch"), ("fedora", "", "other"),
                                            ("ubuntu", "debian", "other"), ("nixos", "", "other"),
                                            ("unknown", "", "other")):
                with self.subTest(distro=distro):
                    release.write_text(f'ID="{distro}"\nNAME="test"\nID_LIKE="{like}"\n')
                    env = dict(os.environ, OS_RELEASE=str(release))
                    result = subprocess.run(["bash", "-c", 'source "$1"; printf "%s" "$FAMILY"', "_",
                                             str(ROOT / "install/lib/distro.sh")],
                                            env=env, text=True, capture_output=True, check=True)
                    self.assertEqual(result.stdout, expected)

    def test_unsupported_installer_stops_before_writes(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
            root = Path(tmp)
            home = root / "home"
            home.mkdir()
            release = root / "os-release"
            for distro in ("fedora", "ubuntu", "nixos"):
                release.write_text(f'ID="{distro}"\nNAME="{distro}"\n')
                env = dict(os.environ, HOME=str(home), TMPDIR=tmp, OS_RELEASE=str(release), SHADOWS_ALLOW_ROOT="1")
                env.pop("HYPRLAND_INSTANCE_SIGNATURE", None)
                for options in (("--yes", "--no-packages"), ("--yes", "--dry-run"), ("--restore",)):
                    with self.subTest(distro=distro, options=options):
                        result = subprocess.run(["bash", str(ROOT / "install.sh"), *options],
                                                env=env, text=True, capture_output=True)
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("not supported", result.stdout + result.stderr)
                        self.assertEqual(list(home.iterdir()), [])
                        self.assertEqual({p.name for p in root.iterdir()}, {"home", "os-release"})

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
