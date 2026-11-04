#!/usr/bin/env python3
"""Check legacy popup settings without touching the user's session."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
popup_defaults = {
    "pos_x": "center", "pos_y": "top", "popup_width": 360, "timeout": 6,
    "critical_sticky": True, "icon_size": 42, "images": True, "popup_style": "glass",
    "accent": True, "colors": "black", "font": "rounded", "font_size": 14,
    "popup_opacity": 0.3, "blur_popups": True, "border": "subtle", "shadow": False,
    "sound": "bubble", "sound_volume": 40,
}
shipped = json.loads((root / "settings/rice/notify.json").read_text())
assert all(shipped[k] == v for k, v in popup_defaults.items())
page = (root / "quickshell/rice-settings/NotificationsPage.qml").read_text()
for title in ("Position", "Popups", "Colors", "Font", "Transparency & blur"):
    assert f'text: "{title}"' in page, title
for removed in ("Notification center", "Notification center style", 'text: "Widgets"', 'value: "match"'):
    assert removed not in page, removed
assert not (root / "quickshell/rice-settings/NcMini.qml").exists()

with tempfile.TemporaryDirectory(prefix="notify-settings-", dir="/tmp/opencode") as home:
    env = dict(os.environ, HOME=home, PATH="/usr/bin:/bin")
    rice = Path(home) / ".config/rice"
    rice.mkdir(parents=True)
    tool = root / "bin/rice-notify"
    state = json.loads(subprocess.check_output([tool, "state"], env=env, text=True))
    assert all(state[k] == v for k, v in popup_defaults.items())
    subprocess.run([tool, "reset"], env=env, check=True)
    reset = json.loads((rice / "notify.json").read_text())
    assert all(reset[k] == v for k, v in popup_defaults.items())
    (rice / "notify.json").write_text(json.dumps({"popup_style": "match", "style": "solid", "w_media": True}))
    state = json.loads(subprocess.check_output([tool, "state"], env=env, text=True))
    assert state["popup_style"] == "solid"
    assert "style" not in state and "w_media" not in state
    subprocess.run([tool, "set", "popup_width", "420"], env=env, check=True)
    assert json.loads((rice / "notify.json").read_text())["popup_width"] == 420
    assert not (Path(home) / ".config/swaync").exists()
    assert not (Path(home) / ".config/hypr").exists()
    for style in ("glass", "solid", "minimal", "pill", "accent", "glow", "island", "light"):
        # Run the generator directly: no swaync-client or Hyprland reload.
        script = "import runpy; m=runpy.run_path(%r); c=m['load'](); c['popup_style']=%r; print(m['css'](c)); print(m['lua_text'](c))" % (str(tool), style)
        output = subprocess.check_output(["python3", "-c", script], env=env, text=True)
        assert "popup style: " + style in output
        assert ".control-center" not in output and ".widget-" not in output
        assert "swaync-notification-window" in output
print("notification settings: OK")
