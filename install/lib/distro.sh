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
esac
# The flavour inside the Arch family, for messages.
DISTRO_FLAVOR="$DISTRO_ID"
case "$FAMILY" in arch) : ;; *) DISTRO_FLAVOR="$FAMILY" ;; esac
# the Hyprland config is Lua, which needs Hyprland 0.55 or newer
HYPR_MIN_MAJOR=0; HYPR_MIN_MINOR=55

# Arch packages, grouped so the installer can explain what it is doing.
PKG_DESKTOP=(hyprland hyprlock hypridle xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent qt5-wayland qt6-wayland)
PKG_SHELL=(quickshell qt6-multimedia waybar swaync awww cava kitty fish fastfetch nautilus matugen)
PKG_TOOLS=(wf-recorder grim slurp wl-clipboard libnotify xdg-user-dirs jq curl python python-pillow playerctl brightnessctl pamixer
           swayosd imagemagick zenity networkmanager bluez bluez-utils pipewire pipewire-pulse wireplumber
           btop cmatrix peaclock pavucontrol gnome-calendar overskride hyprsunset upower power-profiles-daemon)
PKG_FONTS=(ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols noto-fonts noto-fonts-emoji inter-font)
PKG_LOOK=(papirus-icon-theme gnome-themes-extra adw-gtk-theme bibata-cursor-theme-bin)
ARCH_PKGS=("${PKG_DESKTOP[@]}" "${PKG_SHELL[@]}" "${PKG_TOOLS[@]}" "${PKG_FONTS[@]}" "${PKG_LOOK[@]}")

# programs the desktop needs at runtime (shown at the end if something is missing)
NEED_CMDS=(Hyprland hyprlock hypridle waybar qs swaync-client awww matugen cava jq python3 grim slurp wl-copy wf-recorder notify-send)
