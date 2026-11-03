#!/usr/bin/env python3
"""Exercise session state and input regions without executing power actions."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-session-test-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    panel = bar / "components/SessionPanel.qml"
    text = panel.read_text()
    marker = "    SessionButton {\n        id: logout"
    assert text.count(marker) == 1
    test_commands = '''    Component.onCompleted: {
        console.log("LOGOUT_UWSM", JSON.stringify(logoutCommand(["logout"], "hyprland-uwsm")));
        console.log("LOGOUT_OTHER", JSON.stringify(logoutCommand(["logout"], "hyprland")));
        console.log("LOGOUT_CUSTOM", JSON.stringify(logoutCommand(["custom", "arg"], "hyprland-uwsm")));
    }
'''
    panel.write_text(text.replace(marker, test_commands + marker))
    power = bar / "modules/bar/components/Power.qml"
    text = power.read_text().replace("    StateLayer {", "    StateLayer {\n        id: powerLayer", 1)
    text = text.replace("    MaterialIcon {", '''    Timer {
        interval: 700
        running: true
        onTriggered: powerLayer.clicked(null)
    }
    MaterialIcon {''', 1)
    power.write_text(text)
    shell = bar / "shell.qml"
    text = shell.read_text()
    assert text.count("sessionEdge.pressed ? scope.modelData.") == 2
    text = text.replace("sessionEdge.pressed ? scope.modelData.", "(sessionEdge.pressed || sessionEdge.testPressed) ? scope.modelData.")
    text = text.replace("id: sessionEdge\n", "id: sessionEdge\n                    property bool testPressed: false\n", 1)
    marker = "            onFullscreenChanged: {"
    assert text.count(marker) == 1
    test = '''            Timer {
                interval: 1400
                repeat: true
                running: true
                property int phase: 0
                onTriggered: {
                    if (phase === 0) {
                        console.log("SESSION_BUTTON", popoutWin.sessionState.session, sessionPanel.visible, sessionPanel.width > 0, sessionPanel.height > 0);
                        console.log("SESSION_SURFACE", sessionBackground.visible, sessionBackground.width > 0, sessionBackground.height > sessionPanel.height, sessionFill.fillColor === barBackground.color);
                        console.log("SESSION_CONTOUR", sessionBackground.ear === 24, sessionBackground.corner === 28, sessionBackground.height === sessionPanel.height + 80);
                        console.log("SESSION_FOCUS_OPEN", popoutWin.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive);
                        console.log("SESSION_DRAG_REGION_CLOSED", sessionDragRegion.width === 0, sessionDragRegion.height === 0);
                        sessionEdge.testPressed = true;
                        console.log("SESSION_DRAG_REGION_HELD", sessionDragRegion.width === scope.modelData.width, sessionDragRegion.height === scope.modelData.height);
                        sessionEdge.testPressed = false;
                        popoutWin.sessionState.session = false;
                        sessionEdge.handleDrag(-Config.session.dragThreshold - 1);
                        console.log("SESSION_DRAG", popoutWin.sessionState.session);
                    } else {
                        popoutWin.sessionState.session = false;
                        sessionEdge.handleDrag(-Config.session.dragThreshold + 1);
                        console.log("SESSION_SHORT_DRAG", popoutWin.sessionState.session);
                        console.log("SESSION_FOCUS_CLOSED", popoutWin.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None);
                        stop();
                    }
                    phase++;
                }
            }
'''
    shell.write_text(text.replace(marker, test + marker))
    for name in ("home", "runtime", "config", "cache", "state", "data", "bin"):
        (scratch / name).mkdir()
    (scratch / "runtime").chmod(0o700)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch), "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    env = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config", "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state", "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software", "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
    log = scratch / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and proc.poll() is None:
                if "SESSION_SHORT_DRAG" in log.read_text(errors="replace"):
                    break
                time.sleep(0.1)
            result = log.read_text(errors="replace")
            for expected in ("SESSION_BUTTON true true true true", "SESSION_SURFACE true true true true", "SESSION_CONTOUR true true true", "SESSION_FOCUS_OPEN true", "SESSION_DRAG_REGION_CLOSED true true", "SESSION_DRAG_REGION_HELD true true", "SESSION_DRAG true", "SESSION_SHORT_DRAG false", "SESSION_FOCUS_CLOSED true"):
                assert expected in result, result
            for expected in ('LOGOUT_UWSM ["uwsm","stop"]', 'LOGOUT_OTHER ["logout"]', 'LOGOUT_CUSTOM ["custom","arg"]'):
                assert expected in result, result
            for error in ("ReferenceError", "TypeError", "Failed to load configuration"):
                assert error not in result, result
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Session button and drag threshold passed; no power action executed.")
