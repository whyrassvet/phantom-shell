# Licensing and third-party notices

## Phantom Shell

Phantom Shell's combined software work is distributed under the GNU General
Public License, version 3 only (GPL-3.0-only); see the root [LICENSE](../LICENSE).
Individual independent components and assets may have their own terms, as
described below. This notice does not replace or remove their original licenses.

## Shadow's Shell

Phantom Shell is based on [Shadow's Shell](https://github.com/shadowww-dev/shadows-shell),
upstream tag `upstream-2.97`, commit `4202205`. Its original MIT license and
copyright notice are preserved verbatim in [MIT-shadows-shell.txt](MIT-shadows-shell.txt).
MIT-licensed material remains available under its original terms; the combined
work is distributed under GPL-3.0-only.

## Caelestia Shell

The bar, launcher components and private plugin sources include material from
[Caelestia Shell](https://github.com/caelestia-dots/shell), version `v2.5.0`,
commit `d999d4878ee4cec134168e60d913714566a8cfa6`, under GPL-3.0-only. The
upstream GPL text is retained in both
[`quickshell/caelestia-bar/LICENSE`](../quickshell/caelestia-bar/LICENSE) and
[`vendor/caelestia-shell-plugin-v2.5.0/LICENSE`](../vendor/caelestia-shell-plugin-v2.5.0/LICENSE).

Phantom Shell modified the Caelestia material starting on **2026-11-02**. The
changes include adapting the bar to a horizontal layout, popouts, tray and
fullscreen behavior; using Phantom paths and the shadows color palette; adapting
application launcher components; and adjusting plugin configuration defaults.
Details and provenance are recorded in the [bar source notes](../quickshell/caelestia-bar/UPSTREAM.md),
[launcher source notes](../quickshell/caelestia-bar/LAUNCHER-SOURCE.md),
[plugin source notes](../vendor/caelestia-shell-plugin-v2.5.0/PHANTOM-SOURCE.md)
and Git history. These descriptions are not an exhaustive per-file changelog.

## Fonts, sounds and other assets

- `quickshell/caelestia-bar/assets/google-sans-flex/` contains Google Sans Flex;
  its accompanying [license](../quickshell/caelestia-bar/assets/google-sans-flex/LICENSE)
  is SIL Open Font License 1.1. The font's own terms remain applicable.
- The embedded metadata in `config/waybar/scripts/fonts/Skulltype.ttf` and
  `Waycat.ttf` names the SIL Open Font License; a copy of version 1.1 is in
  [OFL-1.1.txt](OFL-1.1.txt). Their metadata does not identify the author or
  the exact source; provenance and any required copyright notices remain to be
  verified before publication. The metadata alone does not establish version 1.1
  or the identity of the rights holder.
- The upstream generation scripts [`make-sounds.py`](../install/tools/make-sounds.py)
  and [`make-sfx.py`](../install/tools/make-sfx.py) describe their generated sounds
  as CC0. Verify provenance of any audio not covered by those scripts separately.
- The inherited wallpapers and other image assets have not been individually
  audited for third-party content or rights. Their presence in the upstream tree
  alone does not establish the provenance of each asset.

The remaining asset and notice review is not complete; this file is not a legal
opinion or confirmation that the repository is ready for public distribution.
