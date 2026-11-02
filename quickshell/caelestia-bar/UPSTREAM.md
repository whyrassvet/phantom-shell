# Caelestia shell sources

`components/`, `services/`, `utils/`, and `assets/` are copied unmodified from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell), tag `v2.5.0`,
commit `d999d4878ee4cec134168e60d913714566a8cfa6`.
These files are distributed under GPL-3.0-only; see `LICENSE` and any notices
within individual assets, including `assets/google-sans-flex/LICENSE`.

The bar module in `modules/bar/` was copied from the same installed version
and subsequently modified for phantom-shell. Vendoring these directories alone
does not make the bar standalone: the C++ QML plugins, CLI calls, settings,
and colour scheme still require further integration and testing.
