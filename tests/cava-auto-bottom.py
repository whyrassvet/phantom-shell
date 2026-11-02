#!/usr/bin/env python3
"""Check visualizer placement using an isolated headless Wayland output."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="cava-bottom-", dir="/tmp/opencode") as tmp:
    path = Path(tmp)
    for name in ("home", "runtime", "config", "cache"):
        (path / name).mkdir()
    (path / "runtime").chmod(0o700)
    shutil.copy(root / "quickshell/rice-desktop/WidgetWindow.qml", path)
    (path / "qmldir").write_text("singleton Sfx 1.0 Sfx.qml\nWidgetWindow 1.0 WidgetWindow.qml\n")
    (path / "Sfx.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function play(s) {} }\n')
    (path / "shell.qml").write_text('''import Quickshell
import QtQuick
ShellRoot {
    WidgetWindow {
        id: w
        autoBottom: true; free: true; passive: true
        bw: 2560; bh: 1440
        wc: ({x: 10, y: 1040, w: 1920, h: 40})
    }
    WidgetWindow {
        id: other
        free: true; visible: false
        wc: ({x: 25, y: 35, w: 300, h: 90})
    }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            const ok = w.px === 0 && w.fw === 2560 && w.py === 1400 && w.dispH === 40
            w.bw = 1920; w.bh = 1080
            w.wc = {x: 200, y: 30, w: 100, h: 80}
            const changed = w.px === 0 && w.fw === 1920 && w.py === 1000 && w.dispH === 80 && other.px === 25 && other.py === 35 && other.fw === 300 && other.fh === 90
            console.log("CAVA_AUTO_BOTTOM", ok, changed, w.px, w.py, w.fw, w.dispH)
            Qt.quit()
        }
    }
}
''')
    cmd = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for key, value in {"HOME": path / "home", "XDG_RUNTIME_DIR": path / "runtime", "XDG_CONFIG_HOME": path / "config", "XDG_CACHE_HOME": path / "cache", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}.items():
        cmd += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        cmd += ["--unsetenv", key]
    cmd += ["cage", "--", "qs", "-n", "-p", str(path)]
    result = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
    print(result.stdout)
    if result.returncode != 0 or "CAVA_AUTO_BOTTOM true true" not in result.stdout:
        raise SystemExit("Visualizer placement test failed")
