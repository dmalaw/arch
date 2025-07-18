#!/bin/bash

# Vérifie les droits root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo."
  exit 1
fi

# Vérification et installation de Hyprland
echo "Installation de Hyprland..."
if pacman -Ss hyprland | grep -q "0.50.0"; then
  pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland
else
  su steeve -c "yay -S --noconfirm hyprland-git xdg-desktop-portal-hyprland-git"
fi

# Installation des outils essentiels
echo "Installation des outils pour Hyprland..."
pacman -S --noconfirm waybar hyprpaper rofi-wayland kitty sddm \
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono ttf-font-awesome \
  dunst thunar mpv pavucontrol brightnessctl corectrl

# Création du dossier de configuration
echo "Configuration de Hyprland pour l'utilisateur steeve..."
mkdir -p /home/steeve/.config/hypr
cp /usr/share/hyprland/hyprland.conf /home/steeve/.config/hypr/hyprland.conf
chown -R steeve:steeve /home/steeve/.config/hypr

# Configuration du moniteur, clavier, etc.
cat <<EOF >> /home/steeve/.config/hypr/hyprland.conf
monitor=DP-2,preferred,auto,1,refresh=165
input {
    kb_layout = us
}
env = WLR_DRM_DEVICES,/dev/dri/card0
exec-once = hyprpaper
exec-once = corectrl
render {
    explicit_sync = 1
}
EOF

# Téléchargement automatique du wallpaper depuis GitHub
echo "Téléchargement du wallpaper personnalisé Arch..."
WALL_URL="https://raw.githubusercontent.com/dmalaw/arch/main/wallpaper.jpg"
WALL_PATH="/home/steeve/wallpaper.jpg"

su steeve -c "curl -L -o '${WALL_PATH}' '${WALL_URL}'"

# Configuration de Hyprpaper avec le wallpaper
echo "Configuration de hyprpaper..."
cat <<EOF > /home/steeve/.config/hypr/hyprpaper.conf
preload = ${WALL_PATH}
wallpaper = DP-2,${WALL_PATH}
EOF

# Permissions
chown steeve:steeve /home/steeve/.config/hypr/hyprpaper.conf /home/steeve/wallpaper.jpg

# Activer SDDM
echo "Activation de SDDM..."
systemctl enable sddm

echo "✅ Hyprland et fond d'écran configurés avec succès !"
