#!/usr/bin/env python3
"""Exercise shadows' theme command through real Matugen into an isolated bar."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STAGE = Path(os.environ["PHANTOM_TEST_STAGE"]).resolve()
MATUGEN = shutil.which("matugen")
if not MATUGEN:
    raise SystemExit("matugen is required")


def wait_for(log, expected, proc, offset=0):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if expected in log.read_text(errors="replace")[offset:]:
            return
        if proc.poll() is not None:
            break
        time.sleep(0.1)
    raise RuntimeError(f"Missing {expected}:\n{log.read_text(errors='replace')}")


with tempfile.TemporaryDirectory(prefix="phantom-colours-e2e-", dir="/tmp/opencode") as tmp:
    path = Path(tmp)
    bar = path / "bar"
    shutil.copytree(ROOT / "quickshell/caelestia-bar", bar)
    colours = bar / "services/Colours.qml"
    code = colours.read_text()
    marker = "        return true;\n    }\n\n    function reloadActiveScheme()"
    assert code.count(marker) == 1
    colours.write_text(code.replace(marker, '        console.log("SHADOWS_COLOURS", colours.m3primary.toString(), colours.m3surface.toString());\n' + marker))
    for name in ("home/.config/matugen", "home/.config/rice", "home/.local/bin", "runtime", "config", "cache", "state", "data", "bin"):
        (path / name).mkdir(parents=True, exist_ok=True)
    (path / "runtime").chmod(0o700)
    palette = path / "home/.config/matugen/phantom-bar.json"
    config = path / "matugen.toml"
    config.write_text("[config]\n[templates.phantom-bar]\n"
                      f"input_path = {json.dumps(str(ROOT / 'config/matugen/templates/phantom-bar.json'))}\n"
                      f"output_path = {json.dumps(str(palette))}\n")
    for name, body in {
        "awww": "exit 0",
        "convert": "echo 50",
        "matugen": f'exec "{MATUGEN}" "$@" --config "$TEST_MATUGEN_CONFIG"',
        "caelestia": 'printf called > "$HOME/cli-called"; exit 1',
    }.items():
        file = path / "bin" / name
        file.write_text("#!/bin/sh\n" + body + "\n")
        file.chmod(0o755)
    rice_colors = path / "home/.local/bin/rice-colors"
    rice_colors.write_text('#!/bin/sh\n[ "$1" != scheme ] || echo "scheme-tonal-spot #0a84c8 @on_accent"\n')
    rice_colors.chmod(0o755)
    env = dict(os.environ, HOME=str(path / "home"), XDG_CONFIG_HOME=str(path / "config"),
               XDG_CACHE_HOME=str(path / "cache"), XDG_STATE_HOME=str(path / "state"),
               XDG_DATA_HOME=str(path / "data"), PATH=f"{path / 'bin'}:{os.environ['PATH']}",
               TEST_MATUGEN_CONFIG=str(config))
    image = ROOT / "quickshell/caelestia-bar/assets/wallpaper.webp"

    def apply():
        subprocess.run(["bash", str(ROOT / "quickshell/hyprquickpaper/commands.sh"), str(image)],
                       env=env, check=True, capture_output=True, text=True, timeout=30)
        data = json.loads(palette.read_text())
        return data["colours"]["primary"].lower(), data["colours"]["surface"].lower()

    first = apply()
    args = ["bwrap", "--ro-bind", "/", "/", "--bind", tmp, tmp, "--dev", "/dev", "--proc", "/proc", "--unshare-net", "--unshare-pid"]
    for item in ("/run/dbus", "/usr/lib/qt6/qml/Caelestia", "/etc/xdg/quickshell/caelestia"):
        if Path(item).is_dir():
            args += ["--tmpfs", item]
    if Path("/usr/bin/caelestia").exists():
        args += ["--ro-bind", str(path / "bin/caelestia"), "/usr/bin/caelestia"]
    settings = {"HOME": path / "home", "XDG_CONFIG_HOME": path / "config", "XDG_CACHE_HOME": path / "cache",
                "XDG_STATE_HOME": path / "state", "XDG_DATA_HOME": path / "data", "XDG_RUNTIME_DIR": path / "runtime",
                "PATH": env["PATH"], "WLR_BACKENDS": "headless", "WLR_RENDERER": "pixman",
                "WLR_LIBINPUT_NO_DEVICES": "1", "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
                "PHANTOM_BAR_CONFIG": bar, "PHANTOM_QML_ROOT": STAGE / "lib/qt6/qml"}
    for key, value in settings.items():
        args += ["--setenv", key, str(value)]
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "LD_PRELOAD", "LD_LIBRARY_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        args += ["--unsetenv", key]
    args += ["cage", "--", str(ROOT / "bin/phantom-bar")]
    log = path / "log"
    with log.open("w") as output:
        proc = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            wait_for(log, "SHADOWS_COLOURS " + " ".join(first), proc)
            (path / "home/.config/rice/color-mode").write_text("ocean\n")
            offset = log.stat().st_size
            second = apply()
            assert second != first
            wait_for(log, "SHADOWS_COLOURS " + " ".join(second), proc, offset)
            assert not (path / "home/cli-called").exists()
        finally:
            os.killpg(proc.pid, 15)
            proc.wait(timeout=10)
    print("Real Matugen palettes from shadows loaded and updated in isolated bar")
