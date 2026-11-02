#!/usr/bin/env python3
"""Check fixed widget corners against screen and widget size changes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="widget-corners-", dir="/tmp/opencode") as tmp:
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
    WidgetWindow { id: clock; fixedCorner: "top-left"; topInset: 40; bw: 2560; bh: 1440; cw: 200; ch: 310; wc: ({x: 5, y: 50}) }
    WidgetWindow { id: resources; fixedCorner: "bottom-left"; bw: 2560; bh: 1440; cw: 160; ch: 380; wc: ({x: 24, y: 1031}) }
    WidgetWindow { id: calendar; fixedCorner: "bottom-right"; bw: 2560; bh: 1440; cw: 340; ch: 340; wc: ({x: 2192, y: 1047}) }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            const initial = clock.px === 25 && clock.py === 65 && resources.px === 25 && resources.py === 1035 && calendar.px === 2195 && calendar.py === 1075
            resources.bw = 1920; resources.bh = 1080; calendar.bw = 1920; calendar.bh = 1080
            calendar.wc = {x: 10, y: 20, scale: 0.5}
            const resized = resources.px === 25 && resources.py === 675 && calendar.px === 1725 && calendar.py === 885
            clock.topInset = 50
            const inset = clock.py === 75
            console.log("FIXED_CORNERS", initial, resized, inset)
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
    if result.returncode != 0 or "FIXED_CORNERS true true true" not in result.stdout:
        raise SystemExit("Fixed widget corners test failed")
