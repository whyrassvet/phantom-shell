#!/usr/bin/env python3
"""Check notification sound selection without playing audio or using the live session."""
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
from unittest.mock import patch

root = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("rice_sound", str(root / "bin/rice-sound"))
spec = importlib.util.spec_from_loader(loader.name, loader)
sound = importlib.util.module_from_spec(spec)
loader.exec_module(sound)

with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
    sound.CFG = str(Path(tmp) / "notify.json")
    sound.STAMP = str(Path(tmp) / "cache/sound.last")
    assert sound.conf() == ("bubble", 40)
    Path(sound.CFG).write_text('{"sound_volume":"invalid"}')
    assert sound.conf() == ("bubble", 40)
    Path(sound.CFG).write_text('{"sound":"bubble","sound_volume":40}')
    with patch.object(sound, "let_go"), patch.object(sound.os, "fork", return_value=0), \
            patch.object(sound.os, "setsid"), patch.object(sound, "play") as play, \
            patch.object(sound, "dnd", side_effect=AssertionError("Phantom must not query SwayNC")):
        sound.notify("Test app")
        play.assert_called_once_with("bubble", 40)
        sound.notify("Test app")  # burst suppression
        sound.notify("brightness")
        assert play.call_count == 1
        Path(sound.STAMP).unlink()
        sound.notify("brightness")
        Path(sound.CFG).write_text('{"sound":"off","sound_volume":40}')
        sound.notify("Test app")
        Path(sound.CFG).write_text('{"sound":"bubble","sound_volume":0}')
        sound.notify("Test app")
        assert play.call_count == 1

print("Notification sound selection, volume, mute and burst suppression passed.")
