#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo."
  exit 1
fi

# CUPS + Détection réseau
pacman -S --noconfirm cups cups-filters ghostscript gsfonts \
  foomatic-db-engine avahi sane

# Pilotes Brother AUR
su steeve -c "yay -S --noconfirm brother-hll2390dw brscan4"

# Services d'impression et détection réseau
systemctl enable --now cups
systemctl enable --now avahi-daemon

# Configuration scanner
read -p "Entrez l'adresse IP de l'imprimante Brother (ex: 192.168.1.42): " IP
brsaneconfig4 -a name=SCANNER model=HL-L2390DW ip=$IP

echo "Allez à http://localhost:631 pour ajouter l'imprimante si non détectée automatiquement."
