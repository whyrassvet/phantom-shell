#!/usr/bin/env python3
"""Exercise the actual QML watcher across monitor and auto-hide changes."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / "quickshell/rice-desktop/shell.qml").read_text()
watcher = source[source.index('    readonly property bool autoHide:'):source.index('    // ---- clock')].replace('Look.lite', 'look.lite')
with tempfile.TemporaryDirectory(prefix="widget-monitor-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    home = p / "home"
    (home / ".local/bin").mkdir(parents=True)
    for name in ("runtime", "config", "cache"):
        (p / name).mkdir()
    (p / "runtime").chmod(0o700)
    script = home / ".local/bin/rice-busy"
    script.write_text('#!/bin/sh\necho "$1" >> "$HOME/started"\n[ "$1" = DP-3 ] && echo 1 || echo 0\nexec sleep 30\n')
    script.chmod(0o755)
    (p / "shell.qml").write_text('''import Quickshell
import Quickshell.Io
import QtQuick
ShellRoot {
    id: root
    property var cfg: ({autoHide: true})
    property var scr: null
    property bool editing: false
    property bool locked: false
    QtObject { id: look; property bool lite: false }
''' + watcher + '''
    Timer { interval: 300; running: true; onTriggered: root.scr = {name: "eDP-1"} }
    Timer { interval: 900; running: true; onTriggered: root.scr = {name: "DP-3"} }
    Timer { interval: 1600; running: true; onTriggered: {
        console.log("MONITOR_RESULT", busyProc.monitor, root.busy, root.hideWidgets)
        root.cfg = {autoHide: false}
    } }
    Timer { interval: 2200; running: true; onTriggered: {
        console.log("DISABLED_RESULT", busyProc.running, root.busy)
        Qt.quit()
    } }
}
''')
    env = {"HOME": home, "XDG_RUNTIME_DIR": p / "runtime", "XDG_CONFIG_HOME": p / "config",
           "XDG_CACHE_HOME": p / "cache", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman",
           "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
    cmd = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for key, value in env.items():
        cmd += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        cmd += ["--unsetenv", key]
    result = subprocess.run(cmd + ["cage", "--", "qs", "-n", "-p", str(p)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
    print(result.stdout)
    assert result.returncode == 0
    assert "MONITOR_RESULT DP-3 true true" in result.stdout
    assert "DISABLED_RESULT false false" in result.stdout
    assert (home / "started").read_text().splitlines() == ["eDP-1", "DP-3"]
