#!/bin/bash

# Vérifie que le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo."
  exit 1
fi

echo "Installation des applications compatibles Wayland, utilitaires et KDE Plasma..."

# Terminal, gestionnaire de fichiers, visionneuse d'image Wayland
pacman -S --noconfirm kitty thunar imv

# KDE Plasma (Wayland)
pacman -S --noconfirm plasma kde-gtk-config kdeplasma-addons \
  xdg-desktop-portal xdg-desktop-portal-kde

# Outils multimédia, audio, luminosité
pacman -S --noconfirm mpv pavucontrol brightnessctl

# Gaming & monitoring
pacman -S --noconfirm steam mangohud

# Polices
pacman -S --noconfirm noto-fonts noto-fonts-emoji \
  ttf-jetbrains-mono ttf-font-awesome

echo "✅ Applications Wayland-friendly et KDE Plasma installées avec succès."
