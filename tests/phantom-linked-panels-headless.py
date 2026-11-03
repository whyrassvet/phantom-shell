#!/usr/bin/env python3
"""Exercise the two shell processes and their IPC without touching the live session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-linked-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    for name in ("home/.config/rice", "runtime", "config/quickshell", "cache", "state/phantom-shell", "data"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    (scratch / "runtime").chmod(0o700)
    bar = scratch / "config/quickshell/caelestia-bar"
    desktop = scratch / "config/quickshell/rice-desktop"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    shutil.copytree(ROOT / "quickshell/rice-desktop", desktop)
    (scratch / "home/.config/rice/hotcorner.json").write_text(json.dumps({"enabled": True, "corner": "bottom-right", "sections": [], "header": False, "width": 400, "close_on_leave": False}))
    (scratch / "home/.config/rice/dashboard.json").write_text(json.dumps({"speed": 1.25}))
    desktop_shell = desktop / "shell.qml"
    text = desktop_shell.read_text().replace('    HotCorner { id: hotCorner;', '''    IpcHandler {
        target: "linkedTest"
        function state(): string { return JSON.stringify({managed: hotCorner.unifiedManaged, visible: hotCorner.visible, enabled: hotCorner.cfg.enabled}) }
    }
    HotCorner { id: hotCorner;''')
    desktop_shell.write_text(text)
    shell = bar / "shell.qml"
    text = shell.read_text()
    text = text.replace('id: corner\n                    anchors.fill: parent', 'id: corner\n                    width: 1920; height: 1080')
    marker = "            onFullscreenChanged: {"
    assert text.count(marker) == 1
    shell.write_text(text.replace(marker, '''            IpcHandler {
                target: "linkedTest"
                function drag(): void { corner.testDrag(-40, 0) }
                function shortDrag(): void { corner.testDrag(-10, 0) }
                function hoverOnly(): void { corner.opened = true }
                function state(): string { return JSON.stringify({open: corner.opened, sidebar: popoutWin.sessionState.sidebar, ready: corner.panelReady, enabled: corner.enabledHere}) }
                function panel(): string { return JSON.stringify(corner.testPanel()) }
                function backgrounds(): string { return JSON.stringify(corner.testBackgrounds()) }
                function close(): void { corner.close() }
            }
''' + marker))
    corner = bar / "components/UnifiedCorner.qml"
    assert "MultiEffect" not in corner.read_text()
    text = corner.read_text().replace('    function close(): void', '''    function testDrag(dx: real, dy: real): void { cornerMouse.dragged = false; cornerMouse.handleDrag(dx, dy); }
    function testBackgrounds(): var {
        const oldCfg = cfg, oldStatus = status;
        cfg = Object.assign({}, cfg, { opacity: 0.44, transparency: true, tint: true });
        status = Object.assign({}, status, { accent: "#a05020" });
        const tinted = { control: String(control.item.backgroundColor), notification: String(notifCard.color) };
        cfg = Object.assign({}, cfg, { transparency: false });
        const opaque = { control: String(control.item.backgroundColor), notification: String(notifCard.color) };
        cfg = oldCfg; status = oldStatus;
        return { tinted: tinted, opaque: opaque };
    }
    function testPanel(): var {
        return { visible: panelWindow.visible, namespace: panelWindow.WlrLayershell.namespace, notifications: shownNotifications, contentOpen: control.item ? control.item.open : false, notificationHeight: notificationHeight, width: panelWindow.implicitWidth, height: panelWindow.implicitHeight };
    }
    function close(): void''')
    text = text.replace('        NotificationPanel {\n', '        NotificationPanel {\n            id: notifCard\n', 1)
    corner.write_text(text)
    bus_config = scratch / "session.conf"
    bus_config.write_text(Path("/usr/share/dbus-1/session.conf").read_text().replace("unix:tmpdir=/tmp", f"unix:tmpdir={scratch}"))
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch), "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    env = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config", "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state", "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software", "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    command = '''qs -p "$1" & desktop=$!
"$3" & bar=$!
sleep 3
printf 'DESKTOP_STATE '; qs ipc -p "$1" call linkedTest state
qs ipc -p "$2" call linkedTest hoverOnly
sleep 1
printf 'HOVER_ONLY '; qs ipc -p "$2" call linkedTest state
printf 'HOVER_PANEL '; qs ipc -p "$2" call linkedTest panel
qs ipc -p "$2" call linkedTest close
sleep 1
qs ipc -p "$2" call linkedTest shortDrag
printf 'SHORT_DRAG '; qs ipc -p "$2" call linkedTest state
qs ipc -p "$2" call linkedTest drag
sleep 0.6
printf 'BAR_STATE '; qs ipc -p "$2" call linkedTest state
printf 'BACKGROUNDS '; qs ipc -p "$2" call linkedTest backgrounds
printf 'BOTH_PANEL '; qs ipc -p "$2" call linkedTest panel
qs ipc -p "$2" call linkedTest close
sleep 0.15
printf 'CLOSED_PANEL '; qs ipc -p "$2" call linkedTest panel
sleep 1
printf 'CLOSED_STATE '; qs ipc -p "$2" call linkedTest state
kill "$bar"
sleep 5
printf 'FALLBACK_STATE '; qs ipc -p "$1" call linkedTest state
kill "$desktop"
wait
'''
    args += ["dbus-run-session", f"--config-file={bus_config}", "--", "cage", "--", "sh", "-c", command, "test", str(desktop), str(bar), str(ROOT / "bin/phantom-bar")]
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=25)
    assert 'DESKTOP_STATE {"managed":true,"visible":false,"enabled":true}' in result.stdout, result.stdout
    assert 'HOVER_ONLY {"open":true,"sidebar":false,"ready":true,"enabled":true}' in result.stdout, result.stdout
    assert 'SHORT_DRAG {"open":false,"sidebar":false,"ready":true,"enabled":true}' in result.stdout, result.stdout
    assert 'BAR_STATE {"open":true,"sidebar":true,"ready":true,"enabled":true}' in result.stdout, result.stdout
    assert 'CLOSED_STATE {"open":false,"sidebar":false,"ready":true,"enabled":true}' in result.stdout, result.stdout
    assert 'FALLBACK_STATE {"managed":false,"visible":true,"enabled":true}' in result.stdout, result.stdout
    backgrounds = json.loads(next(line.split(" ", 1)[1] for line in result.stdout.splitlines() if line.startswith("BACKGROUNDS ")))
    for mode in ("tinted", "opaque"):
        assert backgrounds[mode]["control"] == backgrounds[mode]["notification"], result.stdout
    assert backgrounds["tinted"]["control"] != backgrounds["opaque"]["control"], result.stdout
    def panel_of(label):
        line = next(line for line in result.stdout.splitlines() if line.startswith(label + " "))
        return json.loads(line.split(" ", 1)[1])
    hover = panel_of("HOVER_PANEL")
    both = panel_of("BOTH_PANEL")
    closed = panel_of("CLOSED_PANEL")
    assert hover["visible"] and not hover["notifications"] and hover["contentOpen"], result.stdout
    assert both["visible"] and both["notifications"] and both["contentOpen"], result.stdout
    assert both["namespace"] == "phantom-corner" and 0 < both["notificationHeight"] <= 360, result.stdout
    assert both["height"] > hover["height"] and both["width"] > 0, result.stdout
    assert not closed["visible"] and closed["contentOpen"], result.stdout
    for error in ("ReferenceError", "TypeError", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Unified corner: panel loaded, hover-only, drag and close passed; old trigger resumed after the bar stopped.")
