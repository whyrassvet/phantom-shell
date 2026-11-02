# Caelestia shell plugin source

This directory contains the unmodified upstream top-level `CMakeLists.txt`,
`plugin/` tree and `LICENSE` from [caelestia-dots/shell](https://github.com/caelestia-dots/shell),
tag `v2.5.0`, commit `d999d4878ee4cec134168e60d913714566a8cfa6`.
The upstream code is licensed under GPL-3.0-only; see `LICENSE`.

These sources are a starting point for removing the runtime dependency on the
installed `caelestia-shell` package. They are not yet wired into phantom-shell's
installer or runtime, and the bar still depends on the installed package.

An isolated compilation can be configured with:

```sh
cmake -S vendor/caelestia-shell-plugin-v2.5.0 -B /tmp/opencode/phantom-caelestia-plugin-build \
  -DENABLE_MODULES=plugin -DVERSION=2.5.0
cmake --build /tmp/opencode/phantom-caelestia-plugin-build --parallel 2
```

The plugin requires Qt development modules and system development libraries;
consult `plugin/CMakeLists.txt` and the nested CMake files for the exact list.
Compilation alone does not prove that phantom-shell can run without Caelestia.
