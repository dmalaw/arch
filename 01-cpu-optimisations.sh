#!/bin/bash

# Vérifie sudo
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo."
  exit 1
fi

# Pilotes AMD et microcode Ryzen 5 5600X
pacman -S --noconfirm amd-ucode mesa libva-mesa-driver vulkan-radeon \
  lib32-mesa lib32-libva-mesa-driver lib32-vulkan-radeon

# Optimisations CPU
pacman -S --noconfirm cpupower lm_sensors gamemode
systemctl enable cpupower
echo "governor=performance" > /etc/default/cpupower
sensors-detect --auto

# ZRAM
pacman -S --noconfirm zram-generator
cat <<EOF > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF
systemctl enable systemd-zram-setup@zram0

# Snapper (en environnement chroot idéalement)
pacman -S --noconfirm snapper
snapper --config root create-config /
sed -i 's/^TIMELINE_CREATE="no"/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# Mise à jour GRUB pour le microcode
grub-mkconfig -o /boot/grub/grub.cfg
