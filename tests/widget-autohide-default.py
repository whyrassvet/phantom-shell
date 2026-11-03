#!/usr/bin/env python3
"""Check auto-hide defaults, saved preferences and warning QML loading."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
assert json.loads((root / "settings/rice/desktop.json").read_text())["autoHide"] is True
assert 'cfg.autoHide !== false || Look.lite' in (root / "quickshell/rice-desktop/shell.qml").read_text()
with tempfile.TemporaryDirectory(prefix="widget-autohide-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    home = p / "home"
    home.mkdir()
    env = {**os.environ, "HOME": str(home)}
    cmd = [str(root / "bin/desktop-set"), "state"]
    assert json.loads(subprocess.check_output(cmd, env=env))["autoHide"] is True
    cfg = home / ".config/rice/desktop.json"
    cfg.write_text('{"autoHide": false}')
    assert json.loads(subprocess.check_output(cmd, env=env))["autoHide"] is False

    for name in ("runtime", "config", "cache"):
        (p / name).mkdir()
    (p / "runtime").chmod(0o700)
    for name in ("DesktopPage", "T", "Pill", "ToggleRow", "Tog", "SettingRow", "SegRow", "Seg"):
        shutil.copy(root / f"quickshell/rice-settings/{name}.qml", p)
    (p / "qmldir").write_text("singleton Fonts 1.0 Fonts.qml\nsingleton Sfx 1.0 Sfx.qml\n" + "".join(f"{name} 1.0 {name}.qml\n" for name in ("DesktopPage", "T", "Pill", "ToggleRow", "Tog", "SettingRow", "SegRow", "Seg")))
    (p / "Fonts.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function family(k) { return "sans-serif" } }\n')
    (p / "Sfx.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject { function play(k) {} }\n')
    (p / "shell.qml").write_text('''import Quickshell
import QtQuick
ShellRoot {
    QtObject { id: ctl; property var dst: ({autoHide: true}); property string status: "" }
    DesktopPage { id: page; width: 800; height: 600; ctl: ctl }
    Timer { interval: 1000; running: true; onTriggered: {
        page.requestAutoHide(false)
        console.log("AUTOHIDE_WARNING", page.confirmDisableAutoHide, ctl.dst.autoHide)
        page.confirmDisableAutoHide = false
        console.log("AUTOHIDE_CANCEL", !page.confirmDisableAutoHide, ctl.dst.autoHide)
        Qt.quit()
    } }
}
''')
    cmd = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for k, v in {"HOME": home, "XDG_RUNTIME_DIR": p / "runtime", "XDG_CONFIG_HOME": p / "config", "XDG_CACHE_HOME": p / "cache", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}.items():
        cmd += ["--setenv", k, str(v)]
    for k in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        cmd += ["--unsetenv", k]
    result = subprocess.run(cmd + ["cage", "--", "qs", "-n", "-p", str(p)], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
    print(result.stdout)
    assert result.returncode == 0 and "AUTOHIDE_WARNING true true" in result.stdout and "AUTOHIDE_CANCEL true true" in result.stdout
