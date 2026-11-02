# shellcheck shell=bash
# shellcheck disable=SC2034
# Distro detection + what to install.

DISTRO_ID=linux; DISTRO_NAME=Linux; DISTRO_LIKE=
OS_RELEASE="${OS_RELEASE:-/etc/os-release}"
if [ -r "$OS_RELEASE" ]; then
  # shellcheck disable=SC1090,SC1091
  . "$OS_RELEASE"
  DISTRO_ID="${ID:-linux}"; DISTRO_NAME="${NAME:-Linux}"; DISTRO_LIKE="${ID_LIKE:-}"
fi
FAMILY=other
case " $DISTRO_ID $DISTRO_LIKE " in
  *" arch "*|*" archlinux "*|*" cachyos "*|*" endeavouros "*|*" manjaro "*|*" garuda "*) FAMILY=arch ;;
  *" fedora "*|*" nobara "*|*" ultramarine "*) FAMILY=fedora ;;
esac
# the flavour inside a family, for messages (CachyOS, EndeavourOS, Manjaro, Nobara, Bazzite ...)
DISTRO_FLAVOR="$DISTRO_ID"
case "$FAMILY" in arch|fedora) : ;; *) DISTRO_FLAVOR="$FAMILY" ;; esac
# the Hyprland config is Lua, which needs Hyprland 0.55 or newer
HYPR_MIN_MAJOR=0; HYPR_MIN_MINOR=55
# Fedora Atomic (Bazzite, Silverblue, Kinoite...): packages are layered with rpm-ostree, not dnf
FEDORA_ATOMIC=0
if [ "$FAMILY" = fedora ] && [ -e "${OSTREE_BOOTED:-/run/ostree-booted}" ]; then FEDORA_ATOMIC=1; fi

# Arch packages, grouped so the installer can explain what it is doing.
PKG_DESKTOP=(hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent qt5-wayland qt6-wayland)
PKG_SHELL=(quickshell qt6-multimedia waybar swaync rofi awww cava kitty fish fastfetch nautilus matugen)
PKG_TOOLS=(wf-recorder grim slurp wl-clipboard libnotify xdg-user-dirs jq curl python playerctl brightnessctl pamixer
           swayosd imagemagick zenity networkmanager bluez bluez-utils pipewire pipewire-pulse wireplumber
           btop cmatrix peaclock pavucontrol gnome-calendar overskride hyprsunset upower power-profiles-daemon)
PKG_FONTS=(ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji inter-font)
PKG_LOOK=(papirus-icon-theme gnome-themes-extra adw-gtk-theme bibata-cursor-theme-bin)
ARCH_PKGS=("${PKG_DESKTOP[@]}" "${PKG_SHELL[@]}" "${PKG_TOOLS[@]}" "${PKG_FONTS[@]}" "${PKG_LOOK[@]}")

# programs the desktop needs at runtime (shown at the end if something is missing)
NEED_CMDS=(Hyprland hyprlock hypridle waybar qs swaync-client rofi awww matugen cava jq python3 grim slurp wl-copy wf-recorder notify-send)

# Fedora packages (dnf). Hyprland, its tools and Quickshell come from the nett00n/hyprland COPR (the newest
# Hyprland, needed for the Lua config); awww from scottames/awww. Nerd Font icons and the Bibata cursor are not
# in Fedora: rice-fonts and the installer download them.
# "a|b": the first of these names your Fedora has (Fedora 43 merged rofi-wayland into rofi, for example).
# Quickshell: errornointernet/quickshell is the COPR the Quickshell docs point to (nett00n/hyprland has it too).
# matugen is in Fedora 44 and newer; on older ones the installer downloads it from its GitHub releases.
FEDORA_COPRS=(nett00n/hyprland errornointernet/quickshell scottames/awww)
FPKG_DESKTOP=(hyprland hyprlock hypridle hyprsunset hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
              qt5-qtwayland qt6-qtwayland)
FPKG_SHELL=(quickshell qt6-qtmultimedia waybar SwayNotificationCenter 'rofi-wayland|rofi' awww cava kitty fish fastfetch nautilus matugen)
FPKG_TOOLS=(wf-recorder grim slurp wl-clipboard libnotify xdg-user-dirs jq curl python3 playerctl brightnessctl pamixer
            swayosd ImageMagick zenity NetworkManager bluez pipewire pipewire-pulseaudio wireplumber
            btop cmatrix pavucontrol gnome-calendar upower power-profiles-daemon tar xz unzip)
FPKG_FONTS=(rsms-inter-fonts google-noto-sans-fonts google-noto-emoji-fonts)
FPKG_LOOK=(papirus-icon-theme adw-gtk3-theme)
FEDORA_PKGS=("${FPKG_DESKTOP[@]}" "${FPKG_SHELL[@]}" "${FPKG_TOOLS[@]}" "${FPKG_FONTS[@]}" "${FPKG_LOOK[@]}")
