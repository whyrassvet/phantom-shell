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
            } else if (step === visiblePages.length) {
                win.buildIndex();
                const missing = visiblePages.filter(i => !win.searchIndex.some(e => e.page === i && e.kind === "page"));
                const groups = win.navGroups;
                const members = [].concat.apply([], groups.map(g => g.pages));
                const expected = visiblePages.filter(i => i !== 0 && i !== 15);
                if (groups.map(g => g.name).join("|") !== "Appearance|Desktop|Sound & Alerts|System"
                    || members.length !== expected.length || expected.some(i => members.filter(m => m === i).length !== 1)
                    || !groups[0].pages.includes(2) || win.pages[15].name !== "Update")
                    console.log("NAV_ERROR grouping");
                win.expandedGroups = ({});
                win.page = 2;
                if (!win.expandedGroups.Appearance) console.log("NAV_ERROR auto-expand");
                win.toggleGroup("Appearance");
                if (win.expandedGroups.Appearance) console.log("NAV_ERROR collapse");
                win.toggleGroup("Appearance");
                if (!win.expandedGroups.Appearance) console.log("NAV_ERROR expand");
                win.runSearch("notifications");
                if (!win.results.some(r => r.page === 8)) console.log("NAV_ERROR search");
                const update = updatePage;
                if (!update || update.checked || update.checking) console.log("NAV_ERROR update initial");
                else update.check();
            } else {
                const update = updatePage;
                if (update.checking) return;
                if (!update.checked || update.failure || update.updateInfo.latest !== "9.0" || !update.updateInfo.update)
                    console.log("NAV_ERROR update check");
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
    (p / "home/.local/bin").mkdir(parents=True)
    update = p / "home/.local/bin/rice-update"
    update.write_text('#!/bin/sh\nprintf \'%s\\n\' \'{"installed":"1.0","latest":"9.0","update":true,"error":""}\'\n')
    update.chmod(0o755)
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
    try:
        result = subprocess.run(args + ["cage", "--", "qs", "-n", "-p", str(settings)],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
    except subprocess.TimeoutExpired as exc:
        raise AssertionError(f"Settings test timed out: {exc.stdout!r}") from exc
    assert result.returncode == 0, result.stdout
    assert "NAV_RESULT 15 0 false false" in result.stdout, result.stdout
    for error in ("NAV_ERROR", "ReferenceError", "TypeError", "Failed to load configuration"):
        assert error not in result.stdout, result.stdout
    print("Settings navigation and search passed in isolated headless mode")
