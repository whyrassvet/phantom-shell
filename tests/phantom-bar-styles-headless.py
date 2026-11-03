#!/usr/bin/env python3
"""Check all bar style geometries in an isolated headless compositor."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-styles-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    workspaces_qml = bar / "modules/bar/components/workspaces/Workspaces.qml"
    workspaces_text = workspaces_qml.read_text()
    workspaces_marker = "    Item {\n        anchors.fill: parent"
    assert workspaces_text.count(workspaces_marker) == 1
    workspaces_qml.write_text(workspaces_text.replace(workspaces_marker, '''    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: console.log("STYLE_WORKSPACE_PADDING", BarConfig.style,
            Math.abs((root.implicitWidth - workspaces.implicitWidth) / 2
                - Tokens.padding.extraSmall * (BarConfig.style === "islands" ? 0.5 : 1)) < 0.01)
    }
''' + workspaces_marker))
    bar_qml = bar / "modules/bar/Bar.qml"
    bar_text = bar_qml.read_text()
    bar_marker = "    component EntryWrapper: Item {"
    assert bar_text.count(bar_marker) == 1
    bar_qml.write_text(bar_text.replace(bar_marker, '''    Timer {
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            let backgrounds = true;
            let clockFits = false;
            let clockBackground = false;
            let powerMargin = false;
            let powerIconOffset = false;
            for (let i = 0; i < repeater.count; i++) {
                const entry = repeater.itemAt(i);
                if (!entry) continue;
                const needsBackground = ["logo", "clock", "power"].includes(entry.entryId);
                backgrounds = backgrounds && entry.islandBackground.parent === entry
                    && entry.islandBackground.visible === needsBackground
                    && (!needsBackground || Math.abs(entry.islandBackground.color.a - (Effects.flat ? 1 : Colours.tPalette.m3surface.a)) < 0.01);
                if (["workspaces", "statusIcons"].includes(entry.entryId))
                    backgrounds = backgrounds && Math.abs(entry.item.color.a - (Effects.flat ? 1 : Colours.tPalette.m3surface.a)) < 0.01;
                if (entry.entryId === "power" && i === repeater.count - 1) {
                    powerMargin = entry.Layout.rightMargin === root.spacing + (BarConfig.style === "islands" ? 2 : 0);
                    const icon = entry.item.children.find(child => child.objectName === "powerIcon");
                    powerIconOffset = icon && icon.anchors.horizontalCenterOffset === (BarConfig.style === "islands" ? -1 : 0);
                }
                if (entry.entryId === "clock") {
                    clockFits = entry.item.x >= 0 && entry.item.x + entry.item.width <= entry.width + 0.01;
                    clockBackground = Math.abs(entry.islandBackground.width - entry.item.implicitWidth - 2 * BarConfig.padding - 5) < 0.01
                        && Math.abs(entry.islandBackground.x + entry.islandBackground.width / 2 - entry.item.x - entry.item.width / 2) < 0.01;
                }
            }
            console.log("STYLE_ENTRIES", BarConfig.style, clockFits, BarConfig.style !== "islands" || backgrounds, BarConfig.style !== "islands" || clockBackground);
            console.log("STYLE_POWER_MARGIN", BarConfig.style, powerMargin);
            console.log("STYLE_POWER_ICON", BarConfig.style, powerIconOffset);
        }
    }
''' + bar_marker))
    shell = bar / "shell.qml"
    text = shell.read_text()
    marker = "            onFullscreenChanged: {"
    assert text.count(marker) == 1
    instrumentation = '''            Timer {
                interval: 250
                running: true
                repeat: true
                onTriggered: {
                    const expected = BarConfig.style;
                    console.log("STYLE_CHECK", expected, BarConfig.style === expected,
                        bar.width > 0, barInputRegion.width === bar.width,
                        reservation.exclusiveZone === BarConfig.thickness + BarConfig.topGap,
                        revealArea.y === BarConfig.thickness + BarConfig.topGap + (expected === "flat" ? 0 : 4),
                        expected === "flat" ? bar.width === scope.modelData.width : true,
                        expected === "floating" ? bar.width < scope.modelData.width : true,
                        expected === "island" ? bar.width < scope.modelData.width : true);
                    console.log("STYLE_DIMENSIONS", expected, bar.width, bar.contentWidth, scope.modelData.width, popoutWin.width);
                }
            }
'''
    shell.write_text(text.replace(marker, instrumentation + marker))
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (scratch / name).mkdir()
    (scratch / "runtime").chmod(0o700)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch),
            "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    env = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config",
           "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state",
           "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime",
           "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
           "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
           "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
    log = scratch / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            style_path = scratch / "config/phantom-shell/bar-style"
            style_path.parent.mkdir()
            for style in ("flat", "floating", "islands", "island"):
                style_path.write_text(style + "\n")
                deadline = time.monotonic() + 10
                while time.monotonic() < deadline and proc.poll() is None:
                    current = log.read_text(errors="replace")
                    if (f"STYLE_CHECK {style} true true true true true true true true" in current
                            and f"STYLE_ENTRIES {style} true true true" in current
                            and f"STYLE_POWER_MARGIN {style} true" in current
                            and f"STYLE_POWER_ICON {style} true" in current
                            and f"STYLE_WORKSPACE_PADDING {style} true" in current):
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError(log.read_text(errors="replace"))
            result = log.read_text(errors="replace")
            for style in ("flat", "floating", "islands", "island"):
                assert f"STYLE_CHECK {style} true true true true true true true true" in result, result
                assert f"STYLE_ENTRIES {style} true true true" in result, result
                assert f"STYLE_POWER_MARGIN {style} true" in result, result
                assert f"STYLE_POWER_ICON {style} true" in result, result
                assert f"STYLE_WORKSPACE_PADDING {style} true" in result, result
            for error in ("ReferenceError", "TypeError", "Failed to load configuration"):
                assert error not in result, result
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Bar style geometry passed in headless mode")
