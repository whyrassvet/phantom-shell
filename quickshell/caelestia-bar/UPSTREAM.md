# Caelestia shell sources

`components/`, `services/`, `utils/`, and `assets/` were copied from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell), tag `v2.5.0`,
commit `d999d4878ee4cec134168e60d913714566a8cfa6`.
These files are distributed under GPL-3.0-only; see `LICENSE` and any notices
within individual assets, including `assets/google-sans-flex/LICENSE`.

Local modification: `utils/Paths.qml` uses `phantom-shell` directories for
data, state, cache and configuration rather than the `caelestia` directories.
`services/Wallpapers.qml` no longer invokes the Caelestia CLI automatically
when the wallpaper state file is missing or empty. Explicit wallpaper operations
still use the upstream CLI and require replacement.
`services/Colours.qml` targets the bar layer instead of the Caelestia drawers,
and retains its built-in palette if the phantom-shell scheme is invalid or absent.
Its built-in Material palette is neutral grayscale, except semantic error and
success colours; an explicitly loaded scheme can still override these colours.
Its default dark surfaces follow the current dark Caelestia scheme snapshot,
without reading Caelestia's state at runtime.

The bar module in `modules/bar/` was copied from the same installed version
and subsequently modified for phantom-shell. Vendoring these directories alone
does not make the bar standalone: the C++ QML plugins, CLI calls, settings,
and colour scheme still require further integration and testing.
