#!/usr/bin/env python3
"""Verify the bar follows rice-effects' flat marker in an isolated session."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()


def wait_for(log, expected, proc, offset=0):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        text = log.read_text(errors="replace")[offset:]
        if expected in text:
            return
        if proc.poll() is not None:
            break
        time.sleep(0.1)
    raise RuntimeError(f"Missing {expected}:\n{log.read_text(errors='replace')}")


with tempfile.TemporaryDirectory(prefix="phantom-flat-test-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    shell = bar / "shell.qml"
    source = shell.read_text()
    marker = "                color: Effects.flat ? Colours.palette.m3surface : Colours.tPalette.m3surface"
    assert source.count(marker) == 1
    shell.write_text(source.replace(marker, marker + '\n                onColorChanged: console.log("PHANTOM_FLAT_TEST", Effects.flat, color.a)\n                Component.onCompleted: console.log("PHANTOM_FLAT_TEST", Effects.flat, color.a)'))
    for name in ("home", "runtime", "config", "cache", "state", "data", "bin"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    (scratch / "runtime").chmod(0o700)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch), "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    values = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config", "XDG_CACHE_HOME": scratch / "cache",
              "XDG_STATE_HOME": scratch / "state", "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime",
              "PATH": f"{scratch / 'bin'}:{os.environ['PATH']}", "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman",
              "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
              "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in values.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
    log = scratch / "log"
    marker_file = scratch / "home/.cache/rice/flat"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            wait_for(log, "PHANTOM_FLAT_TEST false 0.5", proc)
            offset = log.stat().st_size
            marker_file.parent.mkdir(parents=True)
            marker_file.write_text("1\n")
            wait_for(log, "PHANTOM_FLAT_TEST true 1", proc, offset)
            offset = log.stat().st_size
            marker_file.unlink()
            wait_for(log, "PHANTOM_FLAT_TEST false 0.5", proc, offset)
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Flat mode switches the bar between opaque and transparent backgrounds")
