#!/usr/bin/env python3
"""Load the real dock and check its scale in an isolated Wayland session."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="phantom-dock-headless-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    desktop = p / "desktop"
    shutil.copytree(root / "quickshell/rice-desktop", desktop)
    (desktop / "shell.qml").write_text('''import Quickshell
import QtQuick
ShellRoot {
    Dock { id: dock; dc: ({ enabled: true, hover: false, media: false, apps: [], scale: 1 }) }
    Timer {
        interval: 500; repeat: true; running: true
        property int step: 0
        onTriggered: {
            if (step === 0) {
                if (dock.implicitHeight !== 88 || dock.dockScale !== 1) console.log("DOCK_ERROR default", dock.implicitHeight)
                dock.dc = ({ enabled: true, hover: false, media: false, apps: [], scale: 2 })
            } else {
                if (dock.implicitHeight !== 148 || dock.dockScale !== 2) console.log("DOCK_ERROR scale", dock.implicitHeight)
                console.log("DOCK_RESULT", dock.implicitHeight, dock.dockScale)
                Qt.quit()
            }
            step++
        }
    }
}
''')
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (p / name).mkdir()
    (p / "runtime").chmod(0o700)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    if Path("/run/dbus").is_dir():
        args += ["--tmpfs", "/run/dbus"]
    env = {"HOME": p / "home", "XDG_RUNTIME_DIR": p / "runtime", "XDG_CONFIG_HOME": p / "config",
           "XDG_CACHE_HOME": p / "cache", "XDG_STATE_HOME": p / "state", "XDG_DATA_HOME": p / "data",
           "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
           "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        args += ["--unsetenv", key]
    result = subprocess.run(args + ["cage", "--", "qs", "-n", "-p", str(desktop)],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    assert result.returncode == 0, result.stdout
    assert "DOCK_RESULT 148 2" in result.stdout, result.stdout
    for error in ("DOCK_ERROR", "ReferenceError", "TypeError", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Dock loads and scales in isolated headless Wayland")
