#!/usr/bin/env python3
"""Smoke-test both shells with isolated HOME and verify monitor wiring."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
desktop = (root / "quickshell/rice-desktop/shell.qml").read_text()
settings = (root / "quickshell/rice-settings/shell.qml").read_text()
assert desktop.count("screen: root.scr") == 11
assert "screen: hotCorner.linkedScreen ?? root.scr" in desktop
assert 'screens[i].name === primaryMonitor' in desktop
assert 'screens.length > 0 ? screens[0] : null' in desktop
assert '{ name: "Monitors"' in settings and 'MonitorsPage { id: monitorPage' in settings
assert '"Monitors"' not in (root / "quickshell/rice-settings/HyprlandPage.qml").read_text()

with tempfile.TemporaryDirectory(prefix="primary-monitor-", dir="/tmp/opencode") as tmp:
    home = Path(tmp)
    for name in ("runtime", "config", "cache"):
        (home / name).mkdir()
    (home / "runtime").chmod(0o700)
    env = {"HOME": home, "XDG_RUNTIME_DIR": home / "runtime", "XDG_CONFIG_HOME": home / "config",
           "XDG_CACHE_HOME": home / "cache", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman",
           "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
    for shell in ("rice-desktop", "rice-settings"):
        cmd = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
        for k, v in env.items():
            cmd += ["--setenv", k, str(v)]
        for k in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
            cmd += ["--unsetenv", k]
        cmd += ["timeout", "5", "cage", "--", "qs", "-n", "-p", str(root / "quickshell" / shell)]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=15)
        print(p.stdout)
        assert "Configuration Loaded" in p.stdout, shell
        assert "Failed to load configuration" not in p.stdout, shell
