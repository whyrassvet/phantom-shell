# Caelestia shell plugin source

This directory contains the upstream top-level `CMakeLists.txt`,
`plugin/` tree and `LICENSE` from [caelestia-dots/shell](https://github.com/caelestia-dots/shell),
tag `v2.5.0`, commit `d999d4878ee4cec134168e60d913714566a8cfa6`.
The upstream code is licensed under GPL-3.0-only; see `LICENSE`.

Local modification: `plugin/src/Caelestia/Config/common.cpp` uses the
`phantom-shell` config directory instead of `caelestia`.
`plugin/src/Caelestia/Config/barconfig.hpp` enables the compact tray, its
background, the microphone indicator, and the keyboard layout by default.
`plugin/src/Caelestia/Config/appearanceconfig.hpp` enables transparency and
sets base opacity to 0.5 by default.

These sources are a starting point for removing the runtime dependency on the
installed `caelestia-shell` package. The separate `bin/phantom-bar` launcher
loads privately staged plugins and has been tested in isolation and in live bar
tests. The main installer builds the plugins, and the Hyprland configuration
starts the bar. Full independence has not been verified in a clean installation;
some other functions still call the CLI.

An isolated compilation can be configured with:

```sh
cmake -S vendor/caelestia-shell-plugin-v2.5.0 -B /tmp/opencode/phantom-caelestia-plugin-build \
  -DENABLE_MODULES=plugin -DVERSION=2.5.0
cmake --build /tmp/opencode/phantom-caelestia-plugin-build --parallel 2
bash tests/smoke-caelestia-plugin.sh /tmp/opencode/phantom-caelestia-plugin-build
```

The plugin requires Qt development modules and system development libraries;
consult `plugin/CMakeLists.txt` and the nested CMake files for the exact list.
The smoke test additionally requires bubblewrap, a C++ compiler, pkg-config,
Qt development libraries, and `/tmp/opencode`. It masks the system Caelestia
QML module and checks that loaded Caelestia libraries come from the build tree.
This test does not run the bar or prove full independence from Caelestia.

`install/build-phantom-plugins.sh BUILD_DIR NEW_PRIVATE_PREFIX` also configures,
builds, and stages the plugins. Both paths must be absolute; the prefix must not
already exist and its parent must exist. The script refuses to replace an
existing prefix. It can reuse a CMake build directory, which it will modify.
The separate `install/install-phantom-plugins.sh` stages versioned builds and
switches `plugin-current` after file checks, retaining previous versions. A full
build has succeeded and the main installer calls this script.

To test an already staged private installation, pass its prefix and QML path:

```sh
bash tests/smoke-caelestia-plugin.sh "$STAGE" "$STAGE/lib/qt6/qml"
```

`bin/phantom-bar` looks under `${XDG_DATA_HOME:-$HOME/.local/share}/phantom-shell/`
using `plugin-current/lib/qt6/qml`, or the legacy `lib/qt6/qml` when there is
no current link; `PHANTOM_QML_ROOT` overrides this. It refuses to start when
private modules or libraries are missing. The main installer builds the plugins,
and the Hyprland configuration starts the launcher. A clean installation without
Caelestia packages and complete functionality still require acceptance testing.
