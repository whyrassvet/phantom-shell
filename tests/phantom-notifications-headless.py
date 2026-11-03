#!/usr/bin/env python3
"""Exercise the notification server on a private bus, never the live session."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-notifs-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    shutil.copytree(ROOT / "quickshell/rice-desktop", scratch / "rice-desktop")
    shell = bar / "shell.qml"
    text = shell.read_text()
    marker = "            onFullscreenChanged: {"
    assert text.count(marker) == 1
    text = text.replace(marker, '''            Timer {
                interval: 2500; running: true
                onTriggered: {
                    console.log("NOTIFICATION_TEST", Notifs.notClosed.length, Notifs.notClosed[0]?.summary, Notifs.popups.length);
                    popoutWin.sessionState.sidebar = true;
                    console.log("NOTIFICATION_PANEL", popoutWin.sessionState.sidebar, Notifs.popups.length);
                    Notifs.notClosed[0].close();
                    console.log("NOTIFICATION_CLEAR", Notifs.notClosed.length);
                    Qt.quit();
                }
            }
''' + marker)
    shell.write_text(text)
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (scratch / name).mkdir()
    (scratch / "runtime").chmod(0o700)
    (scratch / "state/phantom-shell").mkdir()
    bus_config = scratch / "session.conf"
    bus_config.write_text(Path("/usr/share/dbus-1/session.conf").read_text().replace("unix:tmpdir=/tmp", f"unix:tmpdir={scratch}"))
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch), "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    env = {"HOME": scratch / "home", "TMPDIR": scratch, "XDG_CONFIG_HOME": scratch / "config", "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state", "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software", "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["dbus-run-session", f"--config-file={bus_config}", "--", "sh", "-c", 'cage -- "$1" & pid=$!; sleep 1; notify-send --app-name=PhantomTest "Private notification" "Test body"; wait "$pid"', "test", str(ROOT / "bin/phantom-bar")]
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20)
    assert result.returncode == 0, result.stdout
    assert "NOTIFICATION_TEST 1 Private notification 1" in result.stdout, result.stdout
    assert "NOTIFICATION_PANEL true 0" in result.stdout, result.stdout
    assert "NOTIFICATION_CLEAR 0" in result.stdout, result.stdout
    for error in ("ReferenceError", "TypeError", "Binding loop detected", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Private D-Bus notification received; live notification service untouched.")
