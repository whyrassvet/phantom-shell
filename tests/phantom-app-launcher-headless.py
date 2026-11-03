#!/usr/bin/env python3
"""Exercise the Caelestia application search and a safe desktop-entry launch."""
import os
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-app-launcher-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    for name in ("home", "runtime", "config", "cache", "state", "data/applications", "bin"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    (scratch / "runtime").chmod(0o700)
    palette = scratch / "home/.config/matugen/phantom-bar.json"
    palette.parent.mkdir(parents=True)
    def scheme(surface, mode="dark"):
        return json.dumps({"name": "test", "mode": mode, "colours": {"surface": surface}})
    palette.write_text(scheme("#123456"))
    app = scratch / "bin/test-app"
    app.write_text(f"#!/bin/sh\nprintf launched > '{scratch / 'launched'}'\n")
    app.chmod(0o755)
    (scratch / "data/applications/phantom-test.desktop").write_text(
        f"[Desktop Entry]\nType=Application\nName=Phantom Test App\nExec={app}\n"
    )
    qml = bar / "launcher.qml"
    source = qml.read_text()
    background = "            color: Effects.flat ? Colours.palette.m3surface : Colours.tPalette.m3surface"
    assert source.count(background) == 1
    source = source.replace(background, background + '''
            onColorChanged: console.log("PHANTOM_APP_ALPHA", Effects.flat, color.a)
            property color testOutline: border.color
            onTestOutlineChanged: console.log("PHANTOM_OUTLINE", border.width, testOutline.r, testOutline.a)
            Component.onCompleted: {
                console.log("PHANTOM_APP_ALPHA", Effects.flat, color.a);
                console.log("PHANTOM_OUTLINE", border.width, testOutline.r, testOutline.a);
            }''')
    needle = "    id: root\n"
    assert source.count(needle) == 1
    qml.write_text(source.replace(needle, needle + '''
    property color testSurface: Colours.palette.m3surface
    onTestSurfaceChanged: console.log("PHANTOM_APP_SURFACE", testSurface.toString())
    Connections {
        target: launcherState
        function onLauncherChanged() { console.log("PHANTOM_APP_OPEN", launcherState.launcher); }
    }
    Timer {
        interval: 500; running: true
        onTriggered: Quickshell.execDetached([Quickshell.env("PHANTOM_TEST_LAUNCHER")])
    }
    Timer { interval: 1000; running: true; onTriggered: search.text = "stale query" }
    Timer {
        interval: 1500; running: true
        onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.env("PHANTOM_BAR_CONFIG") + "/launcher.qml", "ipc", "call", "phantomLauncher", "close"])
    }
    Timer {
        interval: 2000; running: true
        onTriggered: Quickshell.execDetached([Quickshell.env("PHANTOM_TEST_LAUNCHER")])
    }
    Timer { interval: 2500; running: true; onTriggered: console.log("PHANTOM_APP_QUERY", search.text === "" ? "cleared" : "stale") }
    Timer {
        interval: 3000; running: true
        onTriggered: {
            const results = Apps.search("Phantom Test App");
            console.log("PHANTOM_APP_SEARCH", results.length, results[0]?.name ?? "missing");
            if (results.length === 1) Apps.launch(results[0]);
        }
    }
'''))
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch),
            "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    values = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config",
              "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state",
              "XDG_DATA_HOME": scratch / "data", "XDG_DATA_DIRS": scratch / "data",
              "XDG_RUNTIME_DIR": scratch / "runtime", "WLR_BACKENDS": "headless",
              "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
              "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
              "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml",
              "PHANTOM_TEST_LAUNCHER": ROOT / "bin/phantom-app-launcher"}
    for key, value in values.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE",
                "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-app-launcher"), "--run"]
    log = scratch / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline and not (scratch / "launched").exists() and proc.poll() is None:
                time.sleep(0.1)
            text = log.read_text(errors="replace")
            if (not (scratch / "launched").exists() or "PHANTOM_APP_SEARCH 1 Phantom Test App" not in text
                    or "PHANTOM_APP_SURFACE #123456" not in text or text.count("PHANTOM_APP_OPEN true") != 2
                    or "PHANTOM_APP_OPEN false" not in text or "PHANTOM_APP_QUERY cleared" not in text):
                raise RuntimeError(log.read_text(errors="replace"))
            palette.write_text(scheme("#654321", "light"))
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and "PHANTOM_APP_SURFACE #654321" not in log.read_text(errors="replace") and proc.poll() is None:
                time.sleep(0.1)
            text = log.read_text(errors="replace")
            if "PHANTOM_APP_SURFACE #654321" not in text or any(error in text for error in ("TypeError:", "ReferenceError:", "Unable to assign", "is not a type")):
                raise RuntimeError(text)
            if "PHANTOM_OUTLINE 1 0 " not in text or "PHANTOM_OUTLINE 1 1 " not in text:
                raise RuntimeError(text)
            if "PHANTOM_APP_ALPHA false 0.5" not in text:
                raise RuntimeError(text)
            flat = scratch / "home/.cache/rice/flat"
            flat.parent.mkdir(parents=True)
            flat.write_text("1")
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and "PHANTOM_APP_ALPHA true 1" not in log.read_text(errors="replace") and proc.poll() is None:
                time.sleep(0.1)
            text = log.read_text(errors="replace")
            if "PHANTOM_APP_ALPHA true 1" not in text:
                raise RuntimeError(text)
            offset = len(text)
            flat.unlink()
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline and "PHANTOM_APP_ALPHA false 0.4" not in log.read_text(errors="replace")[offset:] and proc.poll() is None:
                time.sleep(0.1)
            if "PHANTOM_APP_ALPHA false 0.4" not in log.read_text(errors="replace")[offset:]:
                raise RuntimeError(log.read_text(errors="replace"))
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Isolated launcher IPC, app launch, palette reload and flat-mode transparency passed")
