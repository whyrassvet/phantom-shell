#!/usr/bin/env python3
"""Check palette precedence and live reload in an isolated headless bar."""
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()


def wait_for(log, expected, proc, offset=0):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if expected in log.read_text(errors="replace")[offset:]:
            return
        if proc.poll() is not None:
            break
        time.sleep(0.1)
    raise RuntimeError(f"Missing {expected} in headless log:\n{log.read_text(errors='replace')}")


def scheme(primary):
    return json.dumps({"name": "test", "mode": "dark", "colours": {"primary": primary}})


with tempfile.TemporaryDirectory(prefix="phantom-colours-test-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    colours = bar / "services/Colours.qml"
    source = colours.read_text()
    marker = "        return true;\n    }\n\n    function reloadActiveScheme()"
    assert source.count(marker) == 1
    colours.write_text(source.replace(marker, '        console.log("PHANTOM_PALETTE_TEST", colours.m3primary.toString());\n' + marker))
    for name in ("home/.config/matugen", "runtime", "config", "cache", "state/phantom-shell", "data", "bin"):
        (scratch / name).mkdir(parents=True, exist_ok=True)
    (scratch / "runtime").chmod(0o700)
    palette = scratch / "home/.config/matugen/phantom-bar.json"
    palette.write_text(scheme("#123456"))
    (scratch / "state/phantom-shell/scheme.json").write_text(scheme("aabbcc"))
    cli = scratch / "bin/caelestia"
    cli.write_text("#!/bin/sh\nexit 1\n")
    cli.chmod(0o755)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", str(scratch), str(scratch), "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    if Path("/usr/bin/caelestia").exists():
        args += ["--ro-bind", str(cli), "/usr/bin/caelestia"]
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
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            wait_for(log, "PHANTOM_PALETTE_TEST #123456", proc)
            palette.write_text(scheme("#654321"))
            wait_for(log, "PHANTOM_PALETTE_TEST #654321", proc)
            replacement = palette.with_suffix(".new")
            replacement.write_text(scheme("#245678"))
            replacement.replace(palette)
            wait_for(log, "PHANTOM_PALETTE_TEST #245678", proc)
            offset = len(log.read_text(errors="replace"))
            palette.unlink()
            wait_for(log, "PHANTOM_PALETTE_TEST #aabbcc", proc, offset)
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Isolated bar loaded, reloaded and fell back from the shadows palette")
