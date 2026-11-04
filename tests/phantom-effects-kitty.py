#!/usr/bin/env python3
"""Check migration of legacy Kitty markers without touching the live session."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
from unittest.mock import patch

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(dir="/tmp/opencode") as tmp:
    home = Path(tmp)
    kitty = home / ".config/kitty"
    kitty.mkdir(parents=True)
    conf = kitty / "kitty.conf"
    conf.write_text("font_size 12\n# DarkShadow's Shell: blur & transparency switch (keep last)\nglobinclude rice-flat.conf\n")
    loader = importlib.machinery.SourceFileLoader("phantom_effects", str(root / "bin/rice-effects"))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    with patch.dict(os.environ, {"HOME": tmp}):
        loader.exec_module(module)
    module.q = lambda *args, **kwargs: None
    module.kitty(False)
    first = conf.read_text()
    assert "DarkShadow" not in first
    assert first.count("# Phantom Shell: blur & transparency switch (keep last)") == 1
    assert first.count("globinclude rice-flat.conf") == 1
    assert "font_size 12" in first
    module.kitty(False)
    assert conf.read_text() == first
    assert (kitty / "kitty.conf.bak-effects").exists()
print("Kitty legacy marker migration and idempotence passed")
