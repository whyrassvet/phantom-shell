# Application launcher provenance

`modules/launcher/services/Apps.qml` and `modules/launcher/items/AppItem.qml`
are from Caelestia Shell v2.5.0, commit `d999d4878ee4cec134168e60d913714566a8cfa6`,
GPL-3.0-only (see `LICENSE`). `launcher.qml` adapts their application search and
item display for a standalone centered window; upstream commands, calculator,
and wallpaper pages are not yet ported. No Caelestia package is required at
runtime; the privately built Caelestia QML plugins are still required.
