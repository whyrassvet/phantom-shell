#!/usr/bin/env python3
"""Exercise wallpaper IPC and state tracking without modifying the real desktop."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()


def wait_for(log, text, proc, offset=0):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if text in log.read_text(errors="replace")[offset:]:
            return
        if proc.poll() is not None:
            break
        time.sleep(0.1)
    raise RuntimeError(f"Missing {text}:\n{log.read_text(errors='replace')}")


with tempfile.TemporaryDirectory(prefix="phantom-wallpaper-ipc-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    service = bar / "services/Wallpapers.qml"
    source = service.read_text()
    marker = "    property string actualCurrent\n"
    assert source.count(marker) == 1
    service.write_text(source.replace(marker, marker + '    onActualCurrentChanged: console.log("IPC_CURRENT", actualCurrent)\n'))
    shell = bar / "shell.qml"
    source = shell.read_text()
    marker = "    id: root\n"
    assert source.count(marker) == 1
    instrumentation = '''    Timer {
        interval: 1800; running: true
        onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.env("PHANTOM_BAR_CONFIG"), "ipc", "call", "wallpaper", "set", Quickshell.env("TEST_WALL")])
    }
    Timer {
        interval: 4200; running: true
        onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.env("PHANTOM_BAR_CONFIG"), "ipc", "call", "wallpaper", "set", "fail"])
    }
    Timer {
        interval: 3500; running: true
        onTriggered: Quickshell.execDetached(["sh", "-c", 'qs -p "$PHANTOM_BAR_CONFIG" ipc call wallpaper get > "$HOME/ipc-get"'])
    }
    Timer {
        interval: 6000; running: true
        onTriggered: Quickshell.execDetached(["sh", "-c", 'qs -p "$PHANTOM_BAR_CONFIG" ipc call wallpaper set "first queued"; qs -p "$PHANTOM_BAR_CONFIG" ipc call wallpaper set "last queued"'])
    }
'''
    shell.write_text(source.replace(marker, marker + instrumentation))
    for name in ("home/.config/quickshell/hyprquickpaper", "home/.cache", "runtime", "config", "cache", "state/phantom-shell/wallpaper", "data", "bin"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    (scratch / "runtime").chmod(0o700)
    (scratch / "state/phantom-shell/wallpaper/path.txt").write_text("legacy\n")
    backend = scratch / "home/.config/quickshell/hyprquickpaper/commands.sh"
    backend.write_text('#!/bin/sh\n[ "$1" != fail ] || exit 7\nsleep 0.5\nprintf "%s\\n" "$1" > "$HOME/.cache/hyprquickpaper-current"\n')
    cli = scratch / "bin/caelestia"
    cli.write_text('#!/bin/sh\nprintf "unexpected cli\\n" >> "$HOME/cli-called"\nexit 1\n')
    cli.chmod(0o755)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    if Path("/usr/bin/caelestia").exists():
        args += ["--ro-bind", str(cli), "/usr/bin/caelestia"]
    wall = str(scratch / "wall with spaces.png")
    values = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config", "XDG_CACHE_HOME": scratch / "cache",
              "XDG_STATE_HOME": scratch / "state", "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime",
              "PATH": f"{scratch / 'bin'}:{os.environ['PATH']}", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman",
              "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
              "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml", "TEST_WALL": wall}
    for key, value in values.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
    log = scratch / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            wait_for(log, "IPC_CURRENT legacy", proc)
            wait_for(log, "IPC_CURRENT " + wall, proc)
            wait_for(log, "Wallpaper application failed (exit 7)", proc)
            assert (scratch / "home/ipc-get").read_text().strip() == wall
            assert (scratch / "home/.cache/hyprquickpaper-current").read_text().strip() == wall
            assert not (scratch / "home/cli-called").exists()
            wait_for(log, "IPC_CURRENT last queued", proc)
            (scratch / "home/.cache/hyprquickpaper-current").write_text("external\n")
            wait_for(log, "IPC_CURRENT external", proc)
            (scratch / "home/.cache/hyprquickpaper-current").unlink()
            wait_for(log, "IPC_CURRENT legacy", proc, log.read_text(errors="replace").rfind("IPC_CURRENT external"))
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Wallpaper IPC, failure and external changes passed in isolation")
