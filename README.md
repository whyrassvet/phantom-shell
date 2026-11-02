<p align="center">
  <img src="assets/banner-dark.svg" alt="DarkShadow's Shell" width="100%">
</p>

<p align="center">
  <b>A Hyprland rice with its own Quickshell settings app, Waybar, desktop widgets, a dashboard and a dock.</b><br>
  Everything is set with sliders and switches in one app. No config editing.<br>
  Made by <a href="https://www.tiktok.com/@shadoww.dev">shadoww.dev</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Arch_Linux-supported-1793D1?style=for-the-badge&logo=archlinux&logoColor=white" alt="Arch Linux">
  <img src="https://img.shields.io/badge/CachyOS-new-08A283?style=for-the-badge&logo=cachyos&logoColor=white" alt="CachyOS">
</p>
<p align="center">
  <img src="https://img.shields.io/badge/Hyprland-0.55+-58E1FF?style=flat-square" alt="Hyprland">
  <img src="https://img.shields.io/badge/Quickshell-QML-8B7BFF?style=flat-square" alt="Quickshell">
  <img src="https://img.shields.io/github/stars/shadowww-dev/shadows-shell?style=flat-square&color=f5c542" alt="Stars">
  <img src="https://img.shields.io/github/last-commit/shadowww-dev/shadows-shell?style=flat-square" alt="Last commit">
</p>

<p align="center">
  <a href="#install-in-one-minute">Install</a> ·
  <a href="#supported-systems">Systems</a> ·
  <a href="#features">Features</a> ·
  <a href="#keybinds">Keybinds</a> ·
  <a href="docs/INSTALL.md">Docs</a> ·
  <a href="docs/CUSTOMIZE.md">Customize</a>
</p>

---

## Screenshots
<p align="center">
  <img src="assets/screenshot.png" alt="DarkShadow's Shell: desktop with widgets" width="100%">
</p>
<p align="center">
  <img src="assets/screenshot-home.png" alt="The Settings app (SUPER + U) over the desktop widgets" width="100%"><br>
  <sub>The Settings app (<code>SUPER + U</code>) with desktop widgets, calendar and audio visualizer</sub>
</p>
<!-- more screenshots: put the files in assets/ and add them here -->

## Supported systems
The bar, the dashboard, the welcome window and Settings show **your distro's logo** automatically.

| System | Status | How |
| --- | --- | --- |
| **Arch Linux** | supported | `./install.sh` |
| **CachyOS** | new in V2.70 | `./install.sh` (Arch based: its repositories and `paru` are used) |
| **EndeavourOS, Garuda** | Arch route | `./install.sh` |
| **Manjaro** | may not work | its packages are held back, Hyprland can be older than 0.55 |

Only Arch Linux and Arch-based distributions are supported by the installer.

## Install in one minute
**Arch Linux / CachyOS / EndeavourOS**
```bash
sudo pacman -S --needed git base-devel
git clone https://github.com/shadowww-dev/shadows-shell && cd shadows-shell
./install.sh
```

## Features
**Settings app** (`SUPER+U`), fifteen pages and a search: Home, Sfx & sounds, Waybar, Bar layout, Hyprland, Dashboard, Rofi, Theme, Cursors, Notifications, Idle & Lockscreen, Desktop, Hot corners, Interface, Services.

| Area | What you get |
| --- | --- |
| **Waybar** | layout editor (move modules between left, center and right), saved presets, position top or bottom, bar height, opacity |
| **Bar styles** | Flat, Floating, Islands, **One island**; group styles None, Pills, Segmented |
| **Autohide** | bar slides in when the pointer touches the screen edge |
| **Distro logo** | the logo of your distro (Arch, CachyOS, EndeavourOS ...) in the bar, the dashboard, the welcome window and Settings, picked automatically |
| **Hot corner** | touch a screen corner for a panel with Keep Awake, screen recording, screenshots, quick toggles (Wi-Fi, Bluetooth, Do Not Disturb, Gaming mode, microphone, Settings) and now playing; sections, toggles, corner, look and animation are set in Settings > Hot corners |
| **Desktop widgets** | frosted glass over your blurred wallpaper (or plain cards), auto-hide while windows are open; clock, calendar, weather, music, resources (CPU, RAM, GPU), user card, battery and a see-through audio visualizer (Bars, Mirror, Wave, Dots); a widget editor on the desktop to add, move, resize and style them |
| **Dashboard** | slides up from the bottom of the screen (SUPER + ALT + D or push the pointer against the bottom edge): Dashboard (weather, calendar, usage, music), Wallpaper (big wallpaper cards, search, random), Performance (CPU, GPU, storage, network, memory, battery), About (your computer, distro, updates); cards you can remove, add, resize and move, looks Shadow, Graphite, Aurora and Frost |
| **Bar layout** | drag and drop Waybar modules between left, center and right, reorder the system icons, Battery module |
| **Dock** | pinned apps, hover to reveal, media player, tinted icons |
| **Hyprland** | gaps, borders, rounding, blur, shadows and animations from sliders, no config editing |
| **Theme** | 21 color schemes: Auto and Grey from your wallpaper, six monochrome (Mono, Slate, Stone, Steel, Ash, Ink) and thirteen colors (Navy, Ocean, Sky, Teal, Mint, Forest, Lime, Gold, Sunset, Ember, Rose, Orchid, Violet). They recolor Waybar, borders, notifications and the lock screen |
| **Notification center** | Deck: switches (Wi-Fi, Bluetooth, Do Not Disturb, night light, keep awake), power modes, notifications, media, volume and brightness, power buttons; floating or against the edge, left or right, any size, blur and transparency |
| **Notifications** | swaync popups and panel: position, layout, widgets (title, Do Not Disturb, media, volume, quick buttons), size, timeout, icon size, Glass / Solid / Outline look, opacity, radius, blur, live preview and a test button |
| **Sfx & sounds** | interface sounds in the shell's own parts (clicks, switches, sliders, typing), seven packs (Tap, Soft, Pluck, Keys, Crystal, Bubble, Retro), volume, each sound on or off, quiet music for the welcome; ten notification sounds (Glass, Droplet, Chime, Bubble, Marimba, Aurora, Ping, Harp, Keys, Ripple) or Off |
| **Search** | "Search anything!" in Settings finds every setting ("bar position", "blur", "clock font") and jumps to it |
| **Updates** | a notification when a new version is out ("Update is Available!"), version and Update now button in the About tab of the dashboard, `rice-update` in a terminal |
| **Idle & Lockscreen** | lock, screen-off and sleep timers; lock screen with Big / Stacked / Minimal clock in seven fonts (white hours, grey minutes), center or left layout, greeting, avatar, Pill / Box / Line password field, power buttons, screenshot / wallpaper / color background and media, resources, weather and notification lines |
| **Rofi** | 5 themes (Shadow, Graphite, Midnight, Rose, Paper), layouts list / grid / full-width bar, position top, center or bottom, width, rows, corner radius, transparency, blur, font size, icons |
| **Cursors** | Bibata, Hyprcursor themes (Rose Pine) and packs you can download in Settings: Catppuccin, Phinger; live preview |
| **Fonts** | one place to set the main and icon fonts |
| **Welcome intro** | once after installing: night falls over the desktop, a few words, the moon logo draws itself in, "Take a look" opens it up again and Settings starts a short tour (it lights up one part at a time). Play it again with `rice-welcome show`, only the tour: `rice-welcome tour` |
| **Performance & gaming** | one switch turns off all blur and transparency (Hyprland, kitty, Waybar, rofi, notifications, dashboard, hot corner, dock, widgets); Gaming mode with options to keep blur, animations, shadows or gaps, Do Not Disturb (Settings > Services) |
| **Your settings everywhere** | `./sync.sh` saves your Settings choices to `settings/`, `./install.sh` puts them on your other computers (files you changed there are kept) |
| **Installer** | interactive (Install, Update, Choose, Restore), backs up everything, supports Arch Linux and Arch-based distributions, warns when Hyprland is too old |

## Keybinds
`SUPER` is the main modifier.

| Keys | Action |
| --- | --- |
| `SUPER + U` | open **Settings** |
| `SUPER + Q` | terminal |
| `SUPER + E` | file manager |
| `SUPER + R` | app menu |
| `ALT + Space` | app launcher (rofi) |
| `SUPER + C` | close window |
| `SUPER + V` | toggle floating |
| `SUPER + P` | pseudo-tile |
| `SUPER + J` | toggle split direction |
| `SUPER + M` | exit Hyprland |
| `SUPER + ←/→/↑/↓` | move focus |
| `SUPER + 1 … 0` | go to workspace |
| `SUPER + SHIFT + 1 … 0` | move window to workspace |
| `SUPER + S` | show/hide scratchpad |
| `SUPER + SHIFT + S` | move window to scratchpad |
| `SUPER + scroll` | next/previous workspace |
| `SUPER + left mouse` | drag window |
| `SUPER + right mouse` | resize window |
| `ALT + ]` / `ALT + [` | volume up / down |
| `SUPER + F12` / `F11` / `F10` | volume up / down / mute (with on-screen display) |
| media keys | play/pause, next, previous |
| `Fn` volume / brightness keys, headset `+` `-` | volume, mute, microphone, brightness |
| `Print` / `SHIFT + Print` | screenshot of a region / the whole screen |
| `SUPER + SHIFT + R` | record a region (press again to stop) |
| `SUPER + A` | open the hot corner panel |
| `SUPER + ALT + W` | edit desktop widgets (add, move, resize, style) |
| `SUPER + ALT + D` | dashboard (slides up from the bottom; pushing the pointer against the bottom edge opens it too) |
| `SUPER + W` | wallpapers (Wallpaper tab of the dashboard) |

## Installation

### Arch Linux (and CachyOS, EndeavourOS, Garuda)
```bash
sudo pacman -S --needed git base-devel
git clone https://github.com/shadowww-dev/shadows-shell
cd shadows-shell
./install.sh
```
The installer updates your system, installs every package (Hyprland, Quickshell, Waybar, swaync, rofi, kitty, fish, Nautilus, fonts, Papirus icons, Bibata cursor, btop, cava, fastfetch, cmatrix, peaclock and more), uses the AUR helper you have (`paru` comes with CachyOS, or it offers `yay`) for the few AUR packages, copies the configs and sets everything up. At the end it warns you when your Hyprland is older than 0.55. Then log out and pick Hyprland.

### Options
| Flag | What it does |
| --- | --- |
| `--yes` | install everything without questions |
| `--dry-run` | show what would happen, change nothing |
| `--no-packages` | skip the package step |
| `--update` | get the newest version and update apps and scripts (keeps your configs) |
| `--restore` | put back the files from the last backup |

Every file the installer replaces is saved in `~/.config/darkshadows-shell-backup-<time>/`.

### Updating
Run `rice-update` (or `./install.sh --update` in the repo), or press **Update now** in the About tab of the dashboard or in the update notification.

## Layout
| Path | Contents |
| --- | --- |
| `bin/` | helper scripts installed to `~/.local/bin` |
| `quickshell/` | Settings app (`rice-settings`) and widgets/dock (`rice-desktop`) |
| `config/` | dotfiles installed to `~/.config` (Hyprland, Waybar, ...) |
| `install/` | installer UI and distro detection |
| `lua/` | Hyprland add-ons: keybinds, widgets autostart, hot corner |
| `wallpapers/` | original wallpapers, copied to `~/Pictures/Wallpapers` |
| `sounds/` | notification sounds (made by `install/tools/make-sounds.py`, CC0) |
| `VERSION` | the current version, used by the update check |
| `.github/` | CI (shellcheck, dry-run install) and issue template |

## Maintainers
`./sync.sh` copies your current setup from this machine into the repo (paths become `@HOME@`, no username is stored) and scans for secrets. Your choices in Settings go to `settings/`; `./install.sh` applies them on other computers, keeps files you changed there, and `./install.sh --update --use-saved-settings` takes the saved ones anyway.

To release a new version, put the new number in `VERSION` (for example `2.03`) and push. Everyone gets the update notification within a few hours.

## License
Not chosen yet. Add a `LICENSE` file before sharing widely.
