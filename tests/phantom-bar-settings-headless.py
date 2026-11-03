#!/usr/bin/env python3
"""Exercise the bar settings page and persisted style in an isolated HOME."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="phantom-bar-settings-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    for name in ("home", "runtime", "config", "cache"):
        (p / name).mkdir()
    (p / "runtime").chmod(0o700)
    names = ("PhantomBarPage", "SectionTitle", "T", "SettingRow", "SegRow", "Seg")
    for name in names:
        shutil.copy(root / f"quickshell/rice-settings/{name}.qml", p)
    (p / "qmldir").write_text("singleton Fonts 1.0 Fonts.qml\nsingleton Sfx 1.0 Sfx.qml\n" + "".join(f"{name} 1.0 {name}.qml\n" for name in names))
    (p / "Fonts.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function family(k) { return "sans-serif" } }\n')
    (p / "Sfx.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function play(k) {} }\n')
    (p / "shell.qml").write_text('''import Quickshell
import QtQuick
ShellRoot {
    PhantomBarPage { id: page; width: 800; height: 600 }
    Timer { interval: 500; running: true; onTriggered: {
        console.log("BAR_PAGE_DEFAULT", page.style)
        page.selectStyle("islands")
    } }
    Timer { interval: 1800; running: true; onTriggered: {
        console.log("BAR_PAGE_SELECTED", page.style)
        Qt.quit()
    } }
}''')
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    values = {"HOME": p / "home", "XDG_RUNTIME_DIR": p / "runtime", "XDG_CONFIG_HOME": p / "config", "XDG_CACHE_HOME": p / "cache", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
    for key, value in values.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        args += ["--unsetenv", key]
    result = subprocess.run(args + ["cage", "--", "qs", "-n", "-p", str(p)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
    assert result.returncode == 0, result.stdout
    assert "BAR_PAGE_DEFAULT flat" in result.stdout and "BAR_PAGE_SELECTED islands" in result.stdout, result.stdout
    assert (p / "config/phantom-shell/bar-style").read_text() == "islands\n"
    assert "TypeError" not in result.stdout and "ReferenceError" not in result.stdout, result.stdout
    print("Bar settings page saved the selected style in an isolated HOME")
