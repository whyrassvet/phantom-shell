#!/usr/bin/env python3
"""Verify cold background startup and subsequent launcher IPC in isolation."""
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()

with tempfile.TemporaryDirectory(prefix="phantom-app-start-", dir="/tmp/opencode") as tmp:
    scratch = Path(tmp)
    bar = scratch / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (scratch / name).mkdir()
    (scratch / "runtime").chmod(0o700)
    driver = scratch / "driver.sh"
    driver.write_text('''#!/bin/bash
set -euo pipefail
"$PHANTOM_TEST_LAUNCHER" --start
qs -p "$PHANTOM_BAR_CONFIG/launcher.qml" ipc call phantomLauncher isOpen > "$HOME/initial"
"$PHANTOM_TEST_LAUNCHER"
qs -p "$PHANTOM_BAR_CONFIG/launcher.qml" ipc call phantomLauncher isOpen > "$HOME/open"
qs -p "$PHANTOM_BAR_CONFIG/launcher.qml" ipc call phantomLauncher close
qs -p "$PHANTOM_BAR_CONFIG/launcher.qml" ipc call phantomLauncher isOpen > "$HOME/closed"
"$PHANTOM_TEST_LAUNCHER" --start
qs -p "$PHANTOM_BAR_CONFIG/launcher.qml" ipc call phantomLauncher isOpen > "$HOME/restarted"
touch "$HOME/done"
''')
    driver.chmod(0o755)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for path in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(path).is_dir():
            args += ["--tmpfs", path]
    values = {"HOME": scratch / "home", "XDG_CONFIG_HOME": scratch / "config",
              "XDG_CACHE_HOME": scratch / "cache", "XDG_STATE_HOME": scratch / "state",
              "XDG_DATA_HOME": scratch / "data", "XDG_RUNTIME_DIR": scratch / "runtime",
              "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
              "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
              "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml",
              "PHANTOM_TEST_LAUNCHER": ROOT / "bin/phantom-app-launcher"}
    for key, value in values.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE",
                "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    log = scratch / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args + ["cage", "--", str(driver)], stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 20
            while time.monotonic() < deadline and not (scratch / "home/done").exists() and proc.poll() is None:
                time.sleep(0.1)
            if not (scratch / "home/done").exists():
                raise RuntimeError(log.read_text(errors="replace"))
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    for name, expected in (("initial", "false"), ("open", "true"), ("closed", "false"), ("restarted", "false")):
        actual = (scratch / "home" / name).read_text().strip().lower()
        assert actual == expected, (name, actual)
    print("Cold daemon startup and repeated IPC commands passed")
