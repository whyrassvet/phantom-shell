#!/usr/bin/env python3
"""Exercise the notification server on a private bus, never the live session."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()
TEST_DEFAULTS = os.environ.get("PHANTOM_TEST_DEFAULTS") == "1"

with tempfile.TemporaryDirectory(prefix="phantom-notifs-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    shutil.copytree(ROOT / "quickshell/rice-desktop", scratch / "rice-desktop")
    card = bar / "components/NotificationCard.qml"
    card_text = card.read_text()
    assert 'id: actionLabel;' in card_text and 'font.family: root.popup ? "" : root.family' in card_text
    card_text = card_text.replace('    id: root\n', '    id: root\n    property var testFonts: [appText.font.family, summaryText.font.family, bodyText.font.family]\n', 1)
    card_text = card_text.replace('Text { width: parent.width; color: root.secondary;', 'Text { id: appText; width: parent.width; color: root.secondary;', 1)
    card_text = card_text.replace('Text { width: parent.width; color: root.foreground;', 'Text { id: summaryText; width: parent.width; color: root.foreground;', 1)
    card_text = card_text.replace('            text: root.notif?.body ?? ""', '            id: bodyText\n            text: root.notif?.body ?? ""', 1)
    card.write_text(card_text)
    shell = bar / "shell.qml"
    text = shell.read_text()
    marker = "            onFullscreenChanged: {"
    assert text.count(marker) == 1
    text = text.replace(marker, '''            Timer {
                interval: 1400; running: true
                onTriggered: {
                    Notifs.dnd = true;
                    Quickshell.execDetached(["notify-send", "--app-name=DndTest", "DND notification"]);
                }
            }
            Timer {
                interval: 1900; running: true
                onTriggered: {
                    Notifs.dnd = false;
                    Quickshell.execDetached(["notify-send", "--app-name=SilentTest", "--hint=boolean:suppress-sound:true", "Silent notification"]);
                }
            }
            Timer {
                interval: 2500; running: true
                onTriggered: {
                    console.log("NOTIFICATION_TEST", Notifs.notClosed.length, Notifs.notClosed[0]?.summary, Notifs.popups.length);
                    console.log("POPUP_SETTINGS", notificationPopups.width, notificationPopups.x, notificationPopups.y, notificationPopups.atBottom, Notifs.notClosed[0].timer.interval, scope.modelData.width);
                    console.log("POPUP_STYLE", notificationPopups.children[0]?.look);
                    console.log("POPUP_APPEARANCE", notificationPopups.children[0]?.surface, notificationPopups.children[0]?.popupOpacity, notificationPopups.children[0]?.family, notificationPopups.children[0]?.textSize, notificationPopups.children[0]?.layer.enabled);
                    popoutWin.sessionState.sidebar = true;
                    console.log("NOTIFICATION_PANEL", popoutWin.sessionState.sidebar, Notifs.popups.length);
                    for (const n of Notifs.notClosed.slice()) n.close();
                    console.log("NOTIFICATION_CLEAR", Notifs.notClosed.length);
                    Qt.quit();
                }
            }
''' + marker)
    text = text.replace(marker, '''            Loader {
                id: centerFontTest
                active: Notifs.notClosed.length > 0
                sourceComponent: NotificationCard { visible: false; notif: Notifs.notClosed[0] }
            }
''' + marker)
    text = text.replace('console.log("NOTIFICATION_PANEL",', 'console.log("CENTER_FONTS", JSON.stringify(centerFontTest.item.testFonts));\n                    PopupSettings.values = Object.assign({}, PopupSettings.values, {font: "sans"});\n                    console.log("CENTER_FONTS_CHANGED", JSON.stringify(centerFontTest.item.testFonts));\n                    console.log("NOTIFICATION_PANEL",', 1)
    shell.write_text(text)
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (scratch / name).mkdir()
    (scratch / "home/.config/rice").mkdir(parents=True)
    (scratch / "home/.local/bin").mkdir(parents=True)
    sound = scratch / "home/.local/bin/rice-sound"
    sound.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/sound-calls"\n')
    sound.chmod(0o755)
    if not TEST_DEFAULTS:
        (scratch / "home/.config/rice/notify.json").write_text('{"pos_x":"left","pos_y":"bottom","popup_width":420,"timeout":12,"popup_style":"pill","colors":"white","popup_opacity":0.5,"font":"mono","font_size":17,"shadow":true}')
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
    assert "NOTIFICATION_TEST 3 Silent notification 2" in result.stdout, result.stdout
    if TEST_DEFAULTS:
        assert "POPUP_SETTINGS 360" in result.stdout and "false 6000" in result.stdout, result.stdout
        geometry = re.search(r"POPUP_SETTINGS 360 ([\d.]+) [\d.]+ false 6000 ([\d.]+)", result.stdout)
        assert geometry and float(geometry[1]) == (float(geometry[2]) - 360) / 2, result.stdout
        assert "POPUP_STYLE glass" in result.stdout, result.stdout
        assert "POPUP_APPEARANCE black 0.3 Rubik 14 false" in result.stdout, result.stdout
        assert 'CENTER_FONTS ["Rubik","Rubik","Rubik"]' in result.stdout, result.stdout
    else:
        assert "POPUP_SETTINGS 420 12" in result.stdout and "true 12000" in result.stdout, result.stdout
        assert "POPUP_STYLE pill" in result.stdout, result.stdout
        assert "POPUP_APPEARANCE white 0.5 JetBrainsMono Nerd Font 17 true" in result.stdout, result.stdout
        assert 'CENTER_FONTS ["JetBrainsMono Nerd Font","JetBrainsMono Nerd Font","JetBrainsMono Nerd Font"]' in result.stdout, result.stdout
    assert "NOTIFICATION_PANEL true 1" in result.stdout, result.stdout
    assert 'CENTER_FONTS_CHANGED ["Inter","Inter","Inter"]' in result.stdout, result.stdout
    assert "NOTIFICATION_CLEAR 0" in result.stdout, result.stdout
    assert (scratch / "home/sound-calls").read_text().splitlines() == ["phantom-notify PhantomTest"]
    for error in ("ReferenceError", "TypeError", "Binding loop detected", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Private D-Bus notification received; live notification service untouched.")
