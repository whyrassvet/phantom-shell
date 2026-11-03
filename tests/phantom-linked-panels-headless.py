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
                function motion(frac: real): string { return JSON.stringify(corner.testMotion(frac)) }
                function anim(): string { return JSON.stringify(corner.testAnim()) }
                function backgrounds(): string { return JSON.stringify(corner.testBackgrounds()) }
                function close(): void { corner.close() }
            }
''' + marker))
    corner = bar / "components/UnifiedCorner.qml"
    assert "blurEnabled: root.exitBlurEnabled" in corner.read_text()
    text = corner.read_text().replace('    function close(): void', '''    function testDrag(dx: real, dy: real): void { cornerMouse.dragged = false; cornerMouse.handleDrag(dx, dy); }
    function testStop(): void { revealAnim.stop(); notificationAnim.stop(); }
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
    function testAnim(): var {
        return { revealDuration: revealAnim.duration, revealTo: revealAnim.to, revealCurve: revealAnim.easing.bezierCurve, notificationDuration: notificationAnim.duration, notificationTo: notificationAnim.to, revealRunning: revealAnim.running, notificationRunning: notificationAnim.running, speed: speed, contentOpen: control.item ? control.item.open : false };
    }
    function testMotion(frac: real): var {
        testStop();
        reveal = frac; notificationReveal = frac;
        const c = control.mapToItem(root, 0, 0);
        const n = notifCard.mapToItem(root, 0, 0);
        return { control: reveal, notification: notificationReveal, cardHeight: notificationHeight, inputY: inputY, inputX: inputX, controlX: c.x, controlY: c.y, notificationX: n.x, notificationY: n.y, controlFinalY: inputY + panels.height - panelHeight, opacity: panels.opacity, blur: Number(dissolveBlur), blurEnabled: exitBlurEnabled, layerOn: panels.layer.enabled, speed: speed, openDuration: openDuration, closeDuration: closeDuration };
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
printf 'OPEN_ANIM '; qs ipc -p "$2" call linkedTest anim
qs ipc -p "$2" call linkedTest close
sleep 1
qs ipc -p "$2" call linkedTest shortDrag
printf 'SHORT_DRAG '; qs ipc -p "$2" call linkedTest state
qs ipc -p "$2" call linkedTest drag
sleep 0.6
printf 'BAR_STATE '; qs ipc -p "$2" call linkedTest state
printf 'BACKGROUNDS '; qs ipc -p "$2" call linkedTest backgrounds
printf 'BOTH_ANIM '; qs ipc -p "$2" call linkedTest anim
printf 'OPEN_MOTION '; qs ipc -p "$2" call linkedTest motion 0.55
qs ipc -p "$2" call linkedTest close
sleep 0.15
printf 'CLOSE_ANIM '; qs ipc -p "$2" call linkedTest anim
printf 'CLOSE_MOTION '; qs ipc -p "$2" call linkedTest motion 0.45
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
    motions = {}
    for label in ("OPEN_MOTION", "CLOSE_MOTION"):
        line = next(line for line in result.stdout.splitlines() if line.startswith(label + " "))
        motion = json.loads(line.split(" ", 1)[1])
        motions[label] = motion
        assert 0 < motion["control"] < 1 and 0 < motion["notification"] < 1, result.stdout
        assert abs(motion["control"] - motion["notification"]) < 0.15, result.stdout
        # The tile dissolves in place: its geometry must not shrink while closing.
        assert abs(motion["controlX"] - motion["inputX"]) < 1 and abs(motion["notificationX"] - motion["inputX"]) < 1, result.stdout
        assert abs(motion["controlY"] - motion["controlFinalY"]) < 1 and abs(motion["notificationY"] - motion["inputY"]) < 1, result.stdout
        assert abs(motion["opacity"] - motion["control"]) < 0.01, result.stdout
        assert 0 < motion["cardHeight"] <= 360 and motion["inputY"] >= 48, result.stdout
        assert motion["speed"] == 1.25, result.stdout
        assert motion["openDuration"] == 373 and motion["closeDuration"] == 460, result.stdout
    assert motions["CLOSE_MOTION"]["layerOn"] is True, result.stdout
    assert motions["CLOSE_MOTION"]["blurEnabled"] is False, result.stdout
    assert abs(motions["CLOSE_MOTION"]["blur"] - (1 - 0.45) * 0.55) < 0.01, result.stdout
    assert motions["OPEN_MOTION"]["layerOn"] is False, result.stdout
    def anim_of(label):
        line = next(line for line in result.stdout.splitlines() if line.startswith(label + " "))
        return json.loads(line.split(" ", 1)[1])
    open_anim = anim_of("OPEN_ANIM")
    assert open_anim["revealTo"] == 1 and abs(open_anim["revealDuration"] - 298.4) < 1, result.stdout
    assert open_anim["notificationTo"] == 0 and not open_anim["notificationRunning"], result.stdout
    assert [round(v, 2) for v in open_anim["revealCurve"]] == [0.05, 0.7, 0.1, 1.0, 1.0, 1.0], result.stdout
    both_anim = anim_of("BOTH_ANIM")
    assert both_anim["revealTo"] == 1 and both_anim["notificationTo"] == 1, result.stdout
    assert abs(both_anim["revealDuration"] - 298.4) < 1 and abs(both_anim["notificationDuration"] - 298.4) < 1, result.stdout
    close_anim = anim_of("CLOSE_ANIM")
    assert close_anim["revealTo"] == 0 and close_anim["notificationTo"] == 0, result.stdout
    assert close_anim["revealRunning"] and close_anim["notificationRunning"], result.stdout
    assert abs(close_anim["revealDuration"] - 368) < 1 and abs(close_anim["notificationDuration"] - 368) < 1, result.stdout
    assert [round(v, 2) for v in close_anim["revealCurve"]] == [0.45, 0.05, 0.55, 0.95, 1.0, 1.0], result.stdout
    assert close_anim["contentOpen"] is True, result.stdout
    for error in ("ReferenceError", "TypeError", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Unified corner: panel loaded, hover-only, drag and close passed; old trigger resumed after the bar stopped.")
