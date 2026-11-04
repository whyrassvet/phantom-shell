#!/usr/bin/env python3
"""Check Phantom's preview and notification sender branding without a desktop."""
import runpy
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
preview = (ROOT / "quickshell/rice-settings/PopupMock.qml").read_text()
assert 'text: "Phantom Shell"' in preview
assert "DarkShadow" not in preview

hotcorner = runpy.run_path(str(ROOT / "bin/rice-hotcorner"), run_name="branding_test")
notify = hotcorner["notify"]
for available in (True, False):
    calls = []
    with patch.dict(notify.__globals__, {"bg": calls.append}), patch.object(
        notify.__globals__["shutil"], "which", return_value=available
    ):
        notify("Screenshot saved", "test.png")
    assert len(calls) == 1
    assert "Phantom Shell" in calls[0]
    assert "DarkShadow's Shell" not in calls[0]

test_notify = runpy.run_path(str(ROOT / "bin/rice-notify"), run_name="branding_test")["test"]
calls = []
with patch.dict(test_notify.__globals__, {"quiet": calls.append}):
    test_notify()
assert "Phantom Shell" in calls[0]
assert "Hello from Phantom Shell" in calls[0]
assert "DarkShadow's Shell" not in calls[0]
print("Notification branding OK")
