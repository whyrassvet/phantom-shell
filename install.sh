#!/usr/bin/env bash
# DarkShadow's Shell installer.
# Installs on Arch Linux and Arch-based distributions for the current user.
set -Euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RICE_VERSION="$(tr -d ' \r\n' <"$ROOT/VERSION" 2>/dev/null || true)"; RICE_VERSION="${RICE_VERSION#[vV]}"; RICE_VERSION="${RICE_VERSION:-2.02}"
HAVE_VERSION="$(tr -d ' \r\n' 2>/dev/null <"$HOME/.config/rice/version" || true)"; HAVE_VERSION="${HAVE_VERSION#[vV]}"
# shellcheck source=install/lib/ui.sh
. "$ROOT/install/lib/ui.sh"
# shellcheck source=install/lib/distro.sh
. "$ROOT/install/lib/distro.sh"

ASSUME_YES=0; DRY_RUN=0; MODE=install; SKIP_PKGS=0; PULLED=0; TAKE_SETTINGS_ARG=0
usage() {
  cat <<U
DarkShadow's Shell installer V$RICE_VERSION

Usage: ./install.sh [options]
  -y, --yes          install everything, no questions
  -n, --dry-run      show what would happen, change nothing
      --no-packages  skip the package step
      --update       get the newest version and update apps, scripts and packages (keeps your configs)
      --use-saved-settings  take the settings saved in this copy (settings/) even where you changed yours
      --restore      put back the files from the newest backup
  -h, --help         this help
U
}
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    --no-packages) SKIP_PKGS=1 ;;
    --restore) MODE=restore ;;
    --update) MODE=update ;;
    --pulled) MODE=update; PULLED=1 ;;
    --use-saved-settings) TAKE_SETTINGS_ARG=1 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $a"; usage; exit 2 ;;
  esac
done

if [ "$(id -u)" = 0 ] && [ -z "${SHADOWS_ALLOW_ROOT:-}" ]; then
  fail "Run this as your normal user, not root. It installs into your home folder and asks for sudo when needed."
  exit 1
fi

if [ "$FAMILY" != arch ]; then
  fail "$DISTRO_NAME is not supported. This installer requires Arch Linux or an Arch-based distribution."
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BK="$HOME/.config/darkshadows-shell-backup-$STAMP"
LOG="${TMPDIR:-/tmp}/darkshadows-shell-install-$STAMP.log"
: >"$LOG"
IN_HYPR=0; [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1 && IN_HYPR=1
BIN="$HOME/.local/bin"
SUDO_PID=""
cleanup() { [ -n "$SUDO_PID" ] && kill "$SUDO_PID" 2>/dev/null; rm -f "${PKG_SPLIT:-}"; show_cursor; }
trap cleanup EXIT

# ------------------------------------------------------------------ helpers
# ver_newer A B: compare Phantom versions, including prereleases.
ver_newer() {
  python3 "$ROOT/bin/phantom_version.py" "$1" "$2"
}
# put SRC DST: copy one file, fill in @HOME@/@USER@, back up what it replaces
put() {
  local src="$1" dst="$2" rel
  [ "$DRY_RUN" = 1 ] && return 0
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    rel="${dst#"$HOME"/}"
    mkdir -p "$BK/$(dirname "$rel")"
    cp -aL "$dst" "$BK/$rel" 2>/dev/null || true
    [ -L "$dst" ] && rm -f "$dst"
  fi
  mkdir -p "$(dirname "$dst")"
  if grep -qI . "$src" 2>/dev/null; then
    sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$src" >"$dst"
  else
    cp -f "$src" "$dst"
  fi
  [ -x "$src" ] && chmod +x "$dst"
  return 0
}
copy_tree() { # copy_tree SRC_DIR DST_DIR
  local src="$1" dst="$2" f
  [ -d "$src" ] || return 0
  while IFS= read -r -d '' f; do put "$f" "$dst/${f#"$src"/}"; done \
    < <(find -L "$src" -type f ! -name '*.bak*' ! -name '.gitkeep' -print0)
}
# shellcheck source=install/lib/phantom-bar.sh
. "$ROOT/install/lib/phantom-bar.sh"
# shellcheck source=install/lib/phantom-user-config.sh
. "$ROOT/install/lib/phantom-user-config.sh"
missing_cmds() {
  local c out=()
  for c in "${NEED_CMDS[@]}"; do command -v "$c" >/dev/null 2>&1 || out+=("$c"); done
  echo "${out[*]:-}"
}
# run a tool with a time limit so one stuck program can never freeze the installer
t() { timeout "${T:-25}" "$@"; }
# start something in the background, detached from the installer
detach() { setsid -f "$@" >/dev/null 2>&1 </dev/null || true; }
config_dirs() { local d; for d in "$ROOT"/config/*/; do [ -d "$d" ] && basename "$d"; done; }
pretty_dir() {
  case "$1" in
    hypr) echo "Hyprland" ;; waybar) echo "Waybar" ;; swaync) echo "Notifications (swaync)" ;;
    rofi) echo "Rofi" ;; matugen) echo "Matugen colors" ;; kitty) echo "Kitty terminal" ;;
    fastfetch) echo "Fastfetch" ;; fish) echo "Fish shell" ;; waybar-presets) echo "Waybar presets" ;; *) echo "$1" ;;
  esac
}

# ------------------------------------------------------------------ steps
sudo_keepalive() {
  [ "$DRY_RUN" = 1 ] && return 0
  info "Some steps need administrator rights (sudo)."
  sudo -v || { fail "sudo failed, skipping packages"; return 1; }
  ( while true; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_PID=$!
}

PKG_SPLIT="$(mktemp)"
pkg_check() { # writes "repo NAME" / "aur NAME" lines for every package in ARCH_PKGS
  local p
  : >"$PKG_SPLIT"
  for p in "${ARCH_PKGS[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then echo "repo $p"; else echo "aur $p"; fi >>"$PKG_SPLIT"
  done
}
pkg_load() {
  REPO_PKGS=(); AUR_PKGS=()
  local kind p
  while read -r kind p; do
    if [ "$kind" = repo ]; then REPO_PKGS+=("$p"); else AUR_PKGS+=("$p"); fi
  done <"$PKG_SPLIT"
}

# the installed Hyprland is older than the Lua config needs: prints its version, nothing when it is fine or missing
hypr_too_old() {
  command -v Hyprland >/dev/null 2>&1 || return 0
  local v maj min
  v="$(timeout 10 Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  [ -n "$v" ] || return 0
  maj="${v%%.*}"; min="${v#*.}"
  if [ "$maj" -lt "$HYPR_MIN_MAJOR" ] || { [ "$maj" -eq "$HYPR_MIN_MAJOR" ] && [ "$min" -lt "$HYPR_MIN_MINOR" ]; }; then echo "$v"; fi
  return 0
}

# what is special about this flavour of the family (shown once at the start)
flavor_notes() {
  case "$DISTRO_FLAVOR" in
    cachyos)     note "CachyOS: its own repositories are used, and paru (which CachyOS ships) installs the AUR packages." ;;
    endeavouros) note "EndeavourOS: plain Arch with yay or paru, everything is installed from the Arch repositories and the AUR." ;;
    garuda)      note "Garuda: Arch based, paru is used for the AUR packages." ;;
    manjaro)     warn "Manjaro holds packages back for weeks. Hyprland may be older than 0.55 (the Lua config needs 0.55): CachyOS or EndeavourOS work better." ;;
  esac
}

aur_helper() { command -v paru >/dev/null 2>&1 && { echo paru; return; }; command -v yay >/dev/null 2>&1 && echo yay; return 0; }

install_yay() {
  local d
  d="$(mktemp -d)"
  sudo pacman -S --needed --noconfirm git base-devel &&
  timeout 120 git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d/yay-bin" &&
  (cd "$d/yay-bin" && makepkg -si --noconfirm --needed)
  local rc=$?
  rm -rf "$d"
  return $rc
}

step_packages() {
  case "$FAMILY" in
    arch)
      sudo_keepalive || return 0
      if [ "$DRY_RUN" = 1 ]; then
        info "would install ${#ARCH_PKGS[@]} packages: ${ARCH_PKGS[*]}"; return 0
      fi
      task "Updating your system first (Arch needs this before new packages)" sudo pacman -Syu --noconfirm
      task "Checking where each package comes from" pkg_check
      pkg_load
      note "${#REPO_PKGS[@]} from the official repositories, ${#AUR_PKGS[@]} from the AUR"
      if ! task "Installing ${#REPO_PKGS[@]} packages: desktop, shell, tools and fonts" \
           sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"; then
        # one package (a conflict, a typo upstream) must not stop all the others
        warn "Installing them together failed, trying one by one"
        local p failed=()
        for p in "${REPO_PKGS[@]}"; do
          pacman -Qi "$p" >/dev/null 2>&1 && continue
          task "  $p" sudo pacman -S --needed --noconfirm "$p" || failed+=("$p")
        done
        [ "${#failed[@]}" -gt 0 ] && warn "Could not install: ${failed[*]} (see $LOG)"
      fi
      if [ "${#AUR_PKGS[@]}" -gt 0 ]; then
        local helper; helper="$(aur_helper)"
        if [ -z "$helper" ]; then
          warn "These come from the AUR: ${AUR_PKGS[*]}"
          if confirm "Install yay (AUR helper) to get them?"; then
            info "Building yay. Its output is shown below, answer any question it asks."
            if install_yay; then ok "yay is installed"; helper=yay; else fail "yay could not be built"; fi
          fi
        fi
        if [ -n "$helper" ]; then
          local extra=(--needed --noconfirm --sudoloop)
          [ "$helper" = paru ] && extra+=(--skipreview)
          info "Installing ${#AUR_PKGS[@]} AUR packages with $helper: ${AUR_PKGS[*]}"
          note "AUR packages are built on your computer; their output is shown so nothing waits invisibly."
          if "$helper" -S "${extra[@]}" "${AUR_PKGS[@]}"; then ok "AUR packages installed"
          else warn "Some AUR packages failed. Try later: $helper -S ${AUR_PKGS[*]}"; fi
        else
          warn "Skipped AUR packages. Install them later: ${AUR_PKGS[*]}"
        fi
      fi
      # power modes in the notification center (not when TLP or auto-cpufreq already manage power)
      if pacman -Qi power-profiles-daemon >/dev/null 2>&1 && ! pacman -Qi tlp >/dev/null 2>&1 && ! pacman -Qi auto-cpufreq >/dev/null 2>&1; then
        task "Turning on power modes (power-profiles-daemon)" sudo systemctl enable --now power-profiles-daemon.service
      fi
      if pacman -Qi bluez >/dev/null 2>&1; then
        task "Turning on the Bluetooth service" sudo systemctl enable --now bluetooth.service
      fi
      ;;
  esac
}

set_look() {
  local theme=Bibata-Modern-Ice icons=Papirus-Dark gtk=adw-gtk3-dark f
  [ -d /usr/share/themes/adw-gtk3-dark ] || gtk=Adwaita-dark
  mkdir -p "$HOME/.icons/default" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
  printf '[Icon Theme]\nName=Default\nInherits=%s\n' "$theme" >"$HOME/.icons/default/index.theme"
  for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] && cp -n "$f" "$f.bak-darkshadows" 2>/dev/null
    printf '[Settings]\ngtk-application-prefer-dark-theme=1\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-cursor-theme-name=%s\ngtk-cursor-theme-size=24\ngtk-font-name=Inter 11\n' \
      "$gtk" "$icons" "$theme" >"$f"
  done
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk" || true
    gsettings set org.gnome.desktop.interface icon-theme "$icons" || true
    gsettings set org.gnome.desktop.interface cursor-theme "$theme" || true
    gsettings set org.gnome.desktop.interface cursor-size 24 || true
  fi
  # Download Bibata for this user when it is missing.
  if [ ! -d "/usr/share/icons/$theme" ] && [ ! -d "$HOME/.local/share/icons/$theme" ] && [ ! -d "$HOME/.icons/$theme" ]; then
    mkdir -p "$HOME/.local/share/icons"
    curl -fsSL -m 120 "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/$theme.tar.xz" |
      tar -xJ -C "$HOME/.local/share/icons" 2>/dev/null || echo "could not download the $theme cursor"
  fi
  [ -f "$HOME/.config/rice/cursor.json" ] || { mkdir -p "$HOME/.config/rice"; echo '{"theme": "Bibata-Modern-Ice", "size": 24}' >"$HOME/.config/rice/cursor.json"; }
  [ -x "$ROOT/bin/rice-cursor" ] && T=10 t "$ROOT/bin/rice-cursor" restore
  # Nautilus opens folders
  command -v xdg-mime >/dev/null 2>&1 && [ -f /usr/share/applications/org.gnome.Nautilus.desktop ] &&
    xdg-mime default org.gnome.Nautilus.desktop inode/directory
  return 0
}
put_wallpapers() {
  local dir f n=0
  dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
  [ "$dir" = "/Wallpapers" ] && dir="$HOME/Pictures/Wallpapers"
  mkdir -p "$dir"
  for f in "$ROOT"/wallpapers/*; do
    [ -f "$f" ] || continue
    [ -e "$dir/$(basename "$f")" ] || { cp "$f" "$dir/"; n=$((n + 1)); }
  done
  # first start: use a wallpaper from the folder
  if [ ! -s "$HOME/.cache/hyprquickpaper-current" ]; then
    mkdir -p "$HOME/.cache"
    f="$(find "$dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) | sort | head -n1)"
    [ -n "$f" ] && echo "$f" >"$HOME/.cache/hyprquickpaper-current"
  fi
  echo "$n new wallpapers in $dir"
}
quiet_fish() {
  mkdir -p "$HOME/.config/fish/conf.d"
  printf '# DarkShadow'"'"'s Shell: no "Welcome to fish" message\nset -g fish_greeting\n' >"$HOME/.config/fish/conf.d/darkshadows.fish"
}
step_fonts() {
  task "Fonts: Inter, Rubik, Nerd Font icons, clock fonts" timeout 400 "$ROOT/bin/rice-fonts"
  command -v fc-cache >/dev/null 2>&1 && task "Refreshing the font cache" timeout 120 fc-cache -f
  task "Dark theme for apps, Papirus icons, Bibata cursor" set_look
  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then ok "JetBrains Mono Nerd Font (icons) is installed"
  else warn "JetBrains Mono Nerd Font is missing: icons will show as boxes"; fi
}

step_configs() {
  local d n
  n="$(config_dirs | wc -l)"
  if [ "$n" = 0 ]; then warn "This copy has no config files (config/ is empty)"; return 0; fi
  for d in $(config_dirs); do
    task "$(pretty_dir "$d")  ->  ~/.config/$d" copy_tree "$ROOT/config/$d" "$HOME/.config/$d"
  done
  task "Hyprland add-ons (keybinds, hot corner, gaming mode)" copy_lua
  [ -d "$ROOT/wallpapers" ] && task "Wallpapers  ->  ~/Pictures/Wallpapers" put_wallpapers
  task "Fish: no welcome message" quiet_fish
  if [ -d "$ROOT/config/fish" ] && command -v fish >/dev/null 2>&1 && [ "$(basename "${SHELL:-}")" != fish ]; then
    if [ "$ASSUME_YES" != 1 ] && confirm "Make fish your default shell? (the configs are made for it)"; then
      # chsh asks for your password, so it runs in the open (not behind a spinner)
      if [ "$DRY_RUN" = 1 ] || chsh -s "$(command -v fish)"; then ok "Default shell is now fish (from your next login)"
      else warn "Could not change the shell. Run later: chsh -s $(command -v fish)"; fi
    fi
  fi
}
copy_lua() { local f; for f in "$ROOT"/lua/*.lua; do [ -f "$f" ] && put "$f" "$HOME/.config/hypr/$(basename "$f")"; done; return 0; }

# ------------------------------------------------------------------ your saved settings
# settings/ holds what you chose in Settings on the computer that ran ./sync.sh: the Waybar look
# (ui.json), dashboard, widgets, hot corner, notifications, lock screen, rofi, fonts, cursor, effects.
# A file is put in place when you do not have it yet, or when you did not change it since the
# installer put it there last time. Files you changed on this computer are kept, unless you said
# "use the saved settings" (then yours are backed up first, like every other file).
SET_STATE="$HOME/.config/rice/.settings-applied"
TAKE_SETTINGS=0
settings_dst() {
  local rel="${1#"$ROOT/settings/"}"
  case "$rel" in
    rice/*) echo "$HOME/.config/rice/${rel#rice/}" ;;
    waybar/*) echo "$HOME/.config/waybar/${rel#waybar/}" ;;
  esac
}
settings_sum() { sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$1" | sha256sum | cut -c1-16; }
have_settings() { [ -n "$(find "$ROOT/settings" -type f ! -name '.gitkeep' 2>/dev/null | head -n1)" ]; }
apply_settings() { # apply_settings RES: puts the saved settings in place, writes what it did to RES
  local res="$1" f rel dst new have last key
  : >"$res"
  mkdir -p "$SET_STATE"
  while IFS= read -r -d '' f; do
    rel="${f#"$ROOT/settings/"}"; dst="$(settings_dst "$f")"
    [ -n "$dst" ] || continue
    key="$SET_STATE/${rel//\//_}"
    new="$(settings_sum "$f")"
    last="$(cat "$key" 2>/dev/null || true)"
    if [ -f "$dst" ]; then
      have="$(sha256sum <"$dst" | cut -c1-16)"
      if [ "$have" = "$new" ]; then echo "$new" >"$key"; continue; fi
      if [ "$have" != "$last" ] && [ "$TAKE_SETTINGS" != 1 ]; then echo "kept $rel" >>"$res"; continue; fi
    fi
    put "$f" "$dst"
    echo "$new" >"$key"
    echo "set $rel" >>"$res"
  done < <(find "$ROOT/settings" -type f ! -name '.gitkeep' -print0 2>/dev/null)
  # the widget editor never comes back open
  [ -f "$HOME/.config/rice/desktop.json" ] && python3 - "$HOME/.config/rice/desktop.json" <<'PY' 2>/dev/null
import json, sys
p = sys.argv[1]
c = json.load(open(p))
if c.get("editing"):
    c["editing"] = False
    json.dump(c, open(p, "w"))
PY
  return 0
}
step_settings() {
  local sf; sf="$(mktemp)"
  task "Your saved settings: Waybar look, dashboard, widgets, hot corner, lock screen..." apply_settings "$sf"
  local n_set n_kept
  n_set="$(grep -c '^set ' "$sf" 2>/dev/null || true)"; n_kept="$(grep -c '^kept ' "$sf" 2>/dev/null || true)"
  [ "${n_set:-0}" -gt 0 ] && note "$n_set settings files updated"
  if [ "${n_kept:-0}" -gt 0 ]; then
    note "Kept your own (changed on this computer): $(sed -n 's/^kept //p' "$sf" | xargs -n1 basename | tr '\n' ' ')"
    note "To take the saved ones too:  ./install.sh --update --use-saved-settings"
  fi
  if [ "${n_set:-0}" -gt 0 ] && [ "$DRY_RUN" != 1 ]; then
    [ -f "$HOME/.config/waybar/config.jsonc" ] && task "Waybar: your look" t "$BIN/waybar-set" reapply
    [ -x "$BIN/rice-cursor" ] && task "Cursor" t "$BIN/rice-cursor" restore
  fi
  rm -f "$sf"
}

step_apps() {
  local d n
  n="$(find "$ROOT/bin" -maxdepth 1 -type f | wc -l)"
  task "Helper scripts ($n)  ->  ~/.local/bin" copy_bins
  [ -d "$ROOT/sounds" ] && task "Notification sounds  ->  ~/.local/share/rice/sounds" copy_tree "$ROOT/sounds" "$HOME/.local/share/rice/sounds"
  [ -f "$ROOT/assets/icon.png" ] && task "App icon  ->  ~/.local/share/rice/icon.png" put "$ROOT/assets/icon.png" "$HOME/.local/share/rice/icon.png"
  for d in "$ROOT"/quickshell/*/; do
    [ -d "$d" ] || continue
    d="$(basename "$d")"
    case "$d" in
      rice-settings) n="Settings app" ;; rice-desktop) n="Desktop widgets, dock and hot corner" ;;
      rice-welcome) n="Welcome screen" ;; hyprquickpaper) n="Wallpaper picker" ;; *) n="$d" ;;
    esac
    if [ "$d" = caelestia-bar ]; then
      task "$n  ->  ~/.config/quickshell/$d" copy_phantom_bar "$ROOT/quickshell/$d" "$HOME/.config/quickshell/$d"
    else
      task "$n  ->  ~/.config/quickshell/$d" copy_tree "$ROOT/quickshell/$d" "$HOME/.config/quickshell/$d"
    fi
  done
  if ! printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
    warn "\$HOME/.local/bin is not in your PATH. Add it in your shell config (fish: fish_add_path \$HOME/.local/bin)"
  fi
}
copy_bins() { local f; for f in "$ROOT"/bin/*; do [ -f "$f" ] && put "$f" "$BIN/$(basename "$f")"; done; return 0; }

wire_hypr() {
  local lua="$HOME/.config/hypr/hyprland.lua" m
  [ -f "$lua" ] || return 0
  for m in rice-settings rice-desktop rice-keys; do
    if [ -f "$HOME/.config/hypr/$m.lua" ] && ! grep -q "^[[:space:]]*require(\"$m\")" "$lua"; then
      printf '\nrequire("%s")\n' "$m" >>"$lua"
    fi
  done
  return 0
}
patch_colors() {
  local c="$HOME/.config/quickshell/hyprquickpaper/commands.sh"
  [ -f "$c" ] || { echo "no hyprquickpaper, skipped"; return 0; }
  python3 "$ROOT/install/patches/colors-commands.py" "$c"
}
fixup() { python3 "$ROOT/install/lib/fixup.py" >"$1"; }
# extra cursor themes from GitHub into ~/.local/share/icons (skips the ones you have; offline is fine)
cursor_packs() { t "$BIN/rice-cursor" get all --missing >"$1" 2>&1; }
remember_repo() { mkdir -p "$HOME/.config/rice"; echo "$ROOT" >"$HOME/.config/rice/repo"; }
remember_version() { mkdir -p "$HOME/.config/rice"; echo "$RICE_VERSION" >"$HOME/.config/rice/version"; }
first_backup() { mkdir -p "$HOME/.config/rice" "$HOME/.cache/rice"; [ -f "$HOME/.config/rice/.first-backup" ] || echo "$BK" >"$HOME/.config/rice/.first-backup"; }

step_finish() {
  local T=25
  task "Remembering your backup folder" first_backup
  task "Remembering where this copy lives (for updates)" remember_repo
  task "Version V$RICE_VERSION" remember_version
  task "Loading the shell's modules in Hyprland" wire_hypr
  local fx; fx="$(mktemp)"
  task "Fitting the config to this computer" fixup "$fx"
  grep -v '^nothing to fix$' "$fx" 2>/dev/null | while IFS= read -r line; do note "$line"; done
  rm -f "$fx"
  [ "${WANT[4]:-0}" = 1 ] && have_settings && step_settings
  [ -f "$HOME/.config/waybar/config.jsonc" ] && task "Waybar: ${DISTRO_NAME} logo" t "$BIN/waybar-set" distro-icon on
  [ -x "$BIN/desktop-set" ] && task "Desktop widgets settings" t "$BIN/desktop-set" state
  command -v swaync >/dev/null 2>&1 && task "Notifications style" t "$BIN/rice-notify" apply
  command -v hyprlock >/dev/null 2>&1 && task "Lock screen and idle timers" t "$BIN/rice-lock" apply
  command -v rofi >/dev/null 2>&1 && task "Rofi theme" t "$BIN/rice-rofi" apply
  task "Hot corner" t "$BIN/rice-hotcorner" apply
  [ -x "$BIN/desktop-set" ] && task "Dock and widget blur" t "$BIN/desktop-set" dock-blur
  [ -x "$BIN/rice-dashboard" ] && task "Dashboard blur" t "$BIN/rice-dashboard" blur
  task "Theme colors for the wallpaper picker" patch_colors
  # last: it must stay the last module Hyprland loads
  [ -x "$BIN/rice-effects" ] && task "Blur, transparency and gaming mode" t "$BIN/rice-effects" apply --no-reload
  [ -x "$BIN/rice-fonts" ] && T=400 task "Fonts: Inter, Rubik, Material Symbols, Nerd Font icons (skips what you have)" t "$BIN/rice-fonts"
  if [ -x "$BIN/rice-cursor" ]; then
    local cf; cf="$(mktemp)"
    T=240 task "Cursor packs: Rose Pine (Hyprcursor), Catppuccin, Phinger" cursor_packs "$cf"
    grep -v 'already here' "$cf" 2>/dev/null | while IFS= read -r line; do note "$line"; done
    rm -f "$cf"
  fi
  if [ "$IN_HYPR" = 1 ] && [ "$DRY_RUN" != 1 ]; then
    task "Reloading Hyprland" t hyprctl reload
    task "Restarting Waybar and the desktop widgets" restart_shell
  else
    note "Hyprland is not running here, so nothing was reloaded. Everything starts on your next login."
  fi
}
restart_shell() {
  pkill -x waybar 2>/dev/null; pkill -x .waybar-wrapped 2>/dev/null; sleep 0.3
  command -v waybar >/dev/null 2>&1 && detach waybar
  [ -x "$BIN/rice-desktop" ] && T=10 t "$BIN/rice-desktop" restart
  return 0
}

do_restore() {
  local last
  last="$(find "$HOME/.config" -maxdepth 1 -type d \( -name 'darkshadows-shell-backup-*' -o -name 'shadows-shell-backup-*' \) 2>/dev/null | sort | tail -n1 || true)"
  [ -n "$last" ] || { fail "No backup found."; exit 1; }
  title "Restore"
  kv "Backup" "$last"
  confirm "Put these files back over your current ones?" || { warn "Cancelled."; exit 0; }
  [ "$DRY_RUN" = 1 ] || cp -a "$last"/. "$HOME"/
  ok "Restored. Files that did not exist before the install were left in place."
  exit 0
}

# ------------------------------------------------------------------ main
banner
title "Your system"
kv "User" "$USER  ($HOME)"
kv "System" "$DISTRO_NAME"
flavor_notes
if [ "$IN_HYPR" = 1 ]; then kv "Session" "Hyprland is running (changes apply right away)"
else kv "Session" "not in Hyprland (changes apply at next login)"; fi
if [ "$FAMILY" = arch ]; then h="$(aur_helper)"; kv "AUR" "${h:-none yet (yay can be installed for you)}"; fi
[ "$DRY_RUN" = 1 ] && warn "Dry run: nothing will be changed."
[ "$MODE" = restore ] && do_restore

if [ "$MODE" = update ]; then
  title "Update"
  if [ "$PULLED" = 1 ]; then ok "Got the newest version"
  elif [ -d "$ROOT/.git" ] && command -v git >/dev/null 2>&1; then
    old="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo ?)"
    if [ "$DRY_RUN" = 1 ]; then info "would run: git pull"
    elif git -C "$ROOT" pull --ff-only >>"$LOG" 2>&1; then
      new="$(git -C "$ROOT" rev-parse --short HEAD)"
      if [ "$old" != "$new" ]; then
        # new files from GitHub, maybe a new installer too: start the new one
        exec "$ROOT/install.sh" --update --pulled "$@"
      fi
    else
      warn "git pull failed (local changes?). Continuing with the files you have."
    fi
  fi
fi

if [ "$MODE" = update ]; then
  if ver_newer "$RICE_VERSION" "${HAVE_VERSION:-2.01}"; then
    ok "Update V$RICE_VERSION  (you have V${HAVE_VERSION:-2.01})"
  else
    ok "You already have the newest version: V$RICE_VERSION"
  fi
fi

if [ "$MODE" = update ]; then
  WANT=(1 0 0 1 1)
  [ "$SKIP_PKGS" = 1 ] && WANT[0]=0
  if [ "$ASSUME_YES" != 1 ] && confirm "Also replace your config files (Hyprland, Waybar, ...) with the new ones? Your current ones are backed up."; then
    WANT[2]=1
  fi
  # the first update that brings saved settings: ask once (with --yes yours stay)
  if have_settings && [ ! -d "$SET_STATE" ] && [ "$ASSUME_YES" != 1 ] && [ "$IS_TTY" = 1 ] &&
     confirm "Use the settings saved in this copy (Waybar look, dashboard, widgets, hot corner, lock screen)? Yours are backed up."; then
    TAKE_SETTINGS=1
  fi
  MENU_CHOICE=99
else
if [ -n "$HAVE_VERSION" ]; then
  if ver_newer "$RICE_VERSION" "$HAVE_VERSION"; then UPD_HINT="V$HAVE_VERSION  ->  V$RICE_VERSION, keeps your configs"
  else UPD_HINT="you have V$HAVE_VERSION, gets the newest from GitHub"; fi
else UPD_HINT="get the newest version, keeps your configs"; fi
menu_select "What would you like to do?" \
  "Install everything|recommended" \
  "Update|$UPD_HINT" \
  "Choose what to install|" \
  "Restore my previous files|from the last backup" \
  "Quit|"
case "$MENU_CHOICE" in 1) exec "$ROOT/install.sh" --update "$@" ;; 3) do_restore ;; 4) exit 0 ;; esac
WANT=(1 1 1 1 1)
[ "$SKIP_PKGS" = 1 ] && WANT[0]=0
TAKE_SETTINGS=1     # a fresh install takes the saved settings (yours are backed up)
fi
[ "$TAKE_SETTINGS_ARG" = 1 ] && TAKE_SETTINGS=1
if [ "$MENU_CHOICE" = 2 ]; then
  menu_multi "Choose what to install" \
    "Packages|Hyprland, Quickshell, Waybar, tools|${WANT[0]}" \
    "Fonts|Inter, Rubik, Nerd Font icons and clock fonts|1" \
    "Config files|Hyprland, Waybar, notifications, rofi|1" \
    "Apps and scripts|Settings app, widgets, dock, hot corner|1" \
    "Your settings|Waybar look, dashboard, widgets, lock screen (settings/)|1"
  WANT=("${MENU_SEL[@]}")
fi

title "Plan"
[ "${WANT[0]}" = 1 ] && info "Install packages for $DISTRO_NAME"
[ "${WANT[1]}" = 1 ] && info "Install fonts"
[ "${WANT[2]}" = 1 ] && info "Copy config files into ~/.config"
[ "${WANT[3]}" = 1 ] && info "Build private Phantom plugins and install the Settings app, widgets and helper scripts"
[ "${WANT[4]:-0}" = 1 ] && have_settings && info "Use your saved settings (Waybar look, dashboard, widgets, lock screen...)"
info "Finish setup (theme, lock screen, notifications, hot corner)"
note "Files that get replaced are saved in ${BK/#$HOME/~}"
confirm "Start?" || { warn "Cancelled."; exit 0; }

STEP_TOTAL=$(( WANT[0] + WANT[1] + WANT[2] + WANT[3] + 1 ))
n=0
if [ "${WANT[0]}" = 1 ]; then n=$((n + 1)); step "$n" "Packages" "Everything the desktop needs, from your package manager"; step_packages; fi
if [ "${WANT[3]}" = 1 ]; then
  if ! task "Build and activate private Phantom plugins" install_phantom_plugins; then
    fail "Private plugin installation failed; stopping before installing configs or apps. Check the log and active version."
    exit 1
  fi
fi
if [ "${WANT[2]}" = 1 ] || [ "${WANT[3]}" = 1 ]; then
  if ! task "Create personal Phantom Hyprland files if absent" ensure_phantom_user_configs; then
    fail "Could not prepare personal Hyprland files; stopping before installing configs or apps."
    exit 1
  fi
fi
if [ "${WANT[1]}" = 1 ]; then n=$((n + 1)); step "$n" "Fonts" "So text and icons look right"; step_fonts; fi
if [ "${WANT[2]}" = 1 ]; then n=$((n + 1)); step "$n" "Config files" "Your old files are backed up first"; step_configs; fi
if [ "${WANT[3]}" = 1 ]; then n=$((n + 1)); step "$n" "Apps and scripts" "Settings app, desktop widgets and the commands behind them"; step_apps
  [ "${WANT[2]}" = 1 ] || task "Hyprland add-ons (keybinds, hot corner)" copy_lua
fi
n=$((n + 1)); step "$n" "Finishing" "Theme, lock screen, notifications and hot corner"; step_finish

# ------------------------------------------------------------------ summary
miss="$(missing_cmds)"
printf '\n'
hr
if [ "$DRY_RUN" = 1 ]; then
  printf '  %s%sDry run finished.%s Nothing was changed.\n' "$CB" "$CW" "$C0"
else
  if [ "$MODE" = update ] && ver_newer "$RICE_VERSION" "${HAVE_VERSION:-2.01}"; then
    printf '  %s%sDarkShadow'"'"'s Shell updated to V%s%s  (was V%s)\n' "$CB" "$CW" "$RICE_VERSION" "$C0" "${HAVE_VERSION:-2.01}"
  elif [ "$MODE" = update ]; then printf '  %s%sDarkShadow'"'"'s Shell V%s%s  newest version, refreshed\n' "$CB" "$CW" "$RICE_VERSION" "$C0"
  else printf '  %s%sDarkShadow'"'"'s Shell V%s is installed.%s\n' "$CB" "$CW" "$RICE_VERSION" "$C0"; fi
fi
hr
if [ -n "$miss" ]; then warn "Still missing: $miss"; else ok "All needed programs are installed"; fi
old_hypr="$(hypr_too_old)"
if [ -n "$old_hypr" ] && [ "$DRY_RUN" != 1 ]; then
  warn "Hyprland $old_hypr is older than 0.55. The config is written in Lua and needs 0.55 or newer."
  case "$FAMILY" in
    arch)   note "Update it: sudo pacman -Syu hyprland (Manjaro: the new version can take a while to arrive)" ;;
  esac
fi
if [ "$IN_HYPR" = 1 ] && [ "$DRY_RUN" != 1 ]; then
  errs="$(t hyprctl configerrors 2>/dev/null | grep -v '^\s*$' | head -5 || true)"
  if [ -n "$errs" ]; then warn "Hyprland reports config errors:"; printf '%s\n' "$errs" | sed 's/^/        /'; fi
fi
title "Next"
if [ "$IN_HYPR" = 1 ]; then info "Press SUPER + U to open Settings"
else info "Log out and pick Hyprland on the login screen (or type Hyprland on a TTY)"; info "Then press SUPER + U to open Settings"; fi
info "Touch the bottom-right corner of the screen for the hot corner"
[ -d "$BK" ] && info "Undo everything:  ./install.sh --restore"
note "Full log: $LOG"
printf '\n'
# the welcome intro (once): night falls, the moon draws itself in, then Settings opens with a short tour.
# After a new install it plays at the next login (Hyprland starts it), so offer a reboot.
# After an update inside Hyprland it plays right away, if it has not been seen yet.
intro_pending=0
[ -x "$BIN/rice-welcome" ] && [ ! -f "$HOME/.config/rice/welcome-seen" ] && [ ! -f "$HOME/.config/rice/welcome-off" ] && intro_pending=1
if [ "$DRY_RUN" != 1 ]; then
  if [ "$MODE" = update ]; then
    if [ "$intro_pending" = 1 ] && [ "$IN_HYPR" = 1 ]; then info "Starting the welcome intro..."; detach "$BIN/rice-welcome" start 1; fi
  else
    [ "$intro_pending" = 1 ] && info "The welcome intro and a short tour of Settings start when you log in."
    if [ "$ASSUME_YES" != 1 ] && [ "$IS_TTY" = 1 ] && confirm_no "Reboot now?"; then
      info "Rebooting..."
      sleep 1
      systemctl reboot || sudo systemctl reboot || warn "Could not reboot. Reboot yourself to finish."
    else
      note "Reboot (or log out and back in) when you are ready."
    fi
  fi
fi
