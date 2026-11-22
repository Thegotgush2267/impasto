#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------
# 1. Detect Root Distro Family
# ---------------------------------------------------------
DISTRO="lfs"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
        arch|endeavouros|cachyos|manjaro|garuda) DISTRO="arch" ;;
        fedora|nobara|ultramarine|rhel|centos)   DISTRO="fedora" ;;
        ubuntu|pop|linuxmint|elementary|zorin)   DISTRO="ubuntu" ;;
        debian|kali|parrot|mx)                   DISTRO="debian" ;;
        opensuse*|suse|sles)                     DISTRO="suse" ;;
        void)                                    DISTRO="void" ;;
        alpine|postmarketos)                     DISTRO="alpine" ;;
        gentoo|funtoo)                           DISTRO="gentoo" ;;
        nixos)                                   DISTRO="nixos" ;;
        lfs)                                     DISTRO="lfs" ;;
        *)
            case "${ID_LIKE:-}" in
                *arch*)   DISTRO="arch" ;;
                *fedora*) DISTRO="fedora" ;;
                *ubuntu*) DISTRO="ubuntu" ;;
                *debian*) DISTRO="debian" ;;
                *suse*)   DISTRO="suse" ;;
                *gentoo*) DISTRO="gentoo" ;;
            esac
            ;;
    esac
fi

echo "==> Detected root family: $DISTRO"

# ---------------------------------------------------------
# 2. Install Dependencies
# ---------------------------------------------------------
install_deps() {
    case "$DISTRO" in
        arch)
            sudo pacman -Syu --needed --noconfirm \
                git base-devel fish kitty waybar brightnessctl playerctl \
                jq bc grim slurp wl-clipboard qt6-wayland polkit-kde-agent \
                pipewire pipewire-pulse wireplumber networkmanager

            # Auto-detect Broadcom Wi-Fi (older MacBook Pros)
            if lspci 2>/dev/null | grep -qi "Broadcom.*Network"; then
                echo "==> Broadcom Wi-Fi detected — installing broadcom-wl-dkms..."
                sudo pacman -S --needed --noconfirm linux-headers broadcom-wl-dkms
            fi

            if ! command -v yay &>/dev/null; then
                git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
                (cd /tmp/yay-bin && makepkg -si --noconfirm)
                rm -rf /tmp/yay-bin
            fi
            yay -S --needed --noconfirm quickshell-git cava
            ;;

        fedora)
            sudo dnf install -y \
                git @development-tools fish kitty waybar brightnessctl playerctl \
                jq bc grim slurp wl-clipboard cava qt6-qtwayland polkit-kde
            sudo dnf copr enable -y solopasha/hyprland || true
            sudo dnf install -y hyprland quickshell || true
            ;;

        ubuntu|debian)
            sudo apt update && sudo apt install -y \
                git build-essential fish kitty waybar brightnessctl playerctl \
                jq bc grim slurp wl-clipboard cava qt6-wayland-dev-tools
            sudo apt install -y hyprland || echo "NOTE: Build Hyprland & Quickshell from source if missing in this release."
            ;;

        suse)
            sudo zypper install -y \
                git patterns-devel-base-devel_basis fish kitty waybar brightnessctl \
                playerctl jq bc grim slurp wl-clipboard cava hyprland
            ;;

        void)
            sudo xbps-install -Sy \
                git base-devel fish-shell kitty Waybar brightnessctl playerctl \
                jq bc grim slurp wl-clipboard cava hyprland
            ;;

        alpine)
            sudo apk add \
                git build-base fish kitty waybar brightnessctl playerctl \
                jq bc grim slurp wl-clipboard cava hyprland
            ;;

        gentoo)
            sudo emerge --ask=n --noreplace \
                dev-vcs/git app-shells/fish x11-terms/kitty gui-apps/waybar \
                app-misc/brightnessctl media-sound/playerctl app-misc/jq \
                sys-devel/bc gui-apps/grim gui-apps/slurp gui-apps/wl-clipboard \
                media-sound/cava gui-wm/hyprland
            ;;

        nixos)
            echo "==> NixOS detected! Add this to /etc/nixos/configuration.nix:"
            cat << 'EOF'
  programs.hyprland.enable = true;
  programs.fish.enable = true;
  environment.systemPackages = with pkgs; [
    quickshell kitty waybar brightnessctl playerctl
    jq bc grim slurp wl-clipboard cava qt6.qtwayland
  ];
EOF
            ;;

        lfs)
            echo "==> Linux From Scratch / Source system detected."
            MISSING=()
            for bin in Hyprland quickshell fish kitty waybar jq bc grim slurp wl-copy brightnessctl playerctl; do
                command -v "$bin" &>/dev/null || MISSING+=("$bin")
            done
            [ ${#MISSING[@]} -gt 0 ] && echo "WARNING: Compile these first: ${MISSING[*]}"
            ;;
    esac
}

install_deps

# ---------------------------------------------------------
# 3. Backup & Deploy Hyprland, Quickshell, Fish, Kitty & Bin
# ---------------------------------------------------------
echo "==> Backing up existing configs..."
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
for dir in hypr quickshell fish kitty; do
    if [ -d "$HOME/.config/$dir" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$HOME/.config/$dir" "$BACKUP_DIR/"
    fi
done

echo "==> Deploying Impasto dotfiles..."
mkdir -p "$HOME/.config" "$HOME/.local/bin"
cp -rf "$SCRIPT_DIR/.config/"* "$HOME/.config/"
cp -rf "$SCRIPT_DIR/.local/bin/"* "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/"* 2>/dev/null || true

echo "==> Rewriting hardcoded /home/gehans paths to $HOME..."
find "$HOME/.config/hypr" "$HOME/.config/quickshell" "$HOME/.config/fish" "$HOME/.config/kitty" "$HOME/.local/bin" -type f \
    -exec sed -i "s|/home/gehans|$HOME|g" {} + 2>/dev/null || true

# ---------------------------------------------------------
# 4. Register Wayland Session & Default Shell
# ---------------------------------------------------------
if [ "$DISTRO" != "nixos" ] && command -v sudo &>/dev/null; then
    echo "==> Registering Hyprland (Impasto) session..."
    sudo mkdir -p /usr/share/wayland-sessions
    printf '[Desktop Entry]\nName=Hyprland (Impasto)\nComment=Hyprland with Impasto Shell\nExec=Hyprland\nType=Application\nDesktopNames=Hyprland\n' \
        | sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null
fi

if [ "$DISTRO" != "nixos" ] && command -v fish &>/dev/null; then
    FISH_PATH="$(command -v fish)"
    if grep -qx "$FISH_PATH" /etc/shells 2>/dev/null && [ "${SHELL:-}" != "$FISH_PATH" ]; then
        chsh -s "$FISH_PATH" || true
    fi
fi

echo "==> Impasto (Hyprland + Quickshell + Fish + Kitty) deployed on $DISTRO!"
