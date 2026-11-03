# Personal Hyprland settings

The project configuration optionally loads two files from
`${XDG_CONFIG_HOME:-$HOME/.config}/phantom-shell/`. The installer creates the
example files only if absent, including on updates; it does not overwrite existing
files or symlinks. Back them up separately: `sync.sh` does not copy them into the
project.

`hyprland-vars.lua` returns a Lua table. The currently supported fields are
`terminal`, `fileManager` and `menu`, each a command string. Missing fields use
the project defaults. These values affect the corresponding default bindings,
not every application or button in the shell.

```lua
return {
    terminal = "foot",
    fileManager = "thunar",
    menu = "phantom-app-launcher",
}
```

`hyprland-user.lua` runs after the project rules and key bindings, before
`rice-gaming`, which intentionally retains final control over gaming-mode
effects. Use standard Hyprland Lua APIs. To replace an existing key binding,
remove it before adding the new one:

```lua
hl.unbind("SUPER + F")
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
```

After editing, check Lua syntax with `luac -p` and apply with `hyprctl reload`,
then check `hyprctl configerrors`. Configuration errors are not silently ignored.
Other existing customizations in `~/.config/hypr/` are not migrated automatically;
move only desired rules to the personal file after reviewing them.
