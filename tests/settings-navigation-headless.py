#!/usr/bin/env python3
"""Exercise Settings page navigation and search in an isolated compositor."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="phantom-settings-navigation-", dir="/tmp/opencode") as tmp:
    p = Path(tmp)
    settings = p / "settings"
    shutil.copytree(root / "quickshell/rice-settings", settings)
    shell = settings / "shell.qml"
    text = shell.read_text()
    marker = "    function startTour() { page = 0; tour.start() }"
    assert text.count(marker) == 1
    instrument = '''    Timer {
        property int step: 0
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            const visiblePages = win.pages.map((p, i) => p.hidden ? -1 : i).filter(i => i >= 0);
            if (step < visiblePages.length) {
                const idx = visiblePages[step];
                win.page = idx;
                const slot = pagesHolder.children.find(c => c.idx === idx);
                if (!slot || slot.cur !== idx)
                    console.log("NAV_ERROR", idx, win.pages[idx].name);
            } else {
                win.buildIndex();
                const missing = visiblePages.filter(i => !win.searchIndex.some(e => e.page === i && e.kind === "page"));
                console.log("NAV_RESULT", visiblePages.length, missing.length,
                    win.pages.some(p => p.name === "Rofi"), win.searchIndex.some(e => e.pageName === "Rofi"));
                Qt.quit();
            }
            step++;
        }
    }
'''
    shell.write_text(text.replace(marker, instrument + marker))
    for name in ("home", "runtime", "config", "cache", "state", "data"):
        (p / name).mkdir()
    (p / "runtime").chmod(0o700)
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    if Path("/run/dbus").is_dir():
        args += ["--tmpfs", "/run/dbus"]
    env = {"HOME": p / "home", "XDG_RUNTIME_DIR": p / "runtime", "XDG_CONFIG_HOME": p / "config",
           "XDG_CACHE_HOME": p / "cache", "XDG_STATE_HOME": p / "state", "XDG_DATA_HOME": p / "data",
           "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman", "WLR_LIBINPUT_NO_DEVICES": "1",
           "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software"}
    for key, value in env.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE"):
        args += ["--unsetenv", key]
    result = subprocess.run(args + ["cage", "--", "qs", "-n", "-p", str(settings)],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    assert result.returncode == 0, result.stdout
    assert "NAV_RESULT 14 0 false false" in result.stdout, result.stdout
    for error in ("NAV_ERROR", "ReferenceError", "TypeError", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Settings navigation and search passed in isolated headless mode")
