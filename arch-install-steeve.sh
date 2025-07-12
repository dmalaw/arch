#!/bin/bash
set -e

# ---- Clavier US et miroir ----
loadkeys us
reflector --country Canada --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# ---- Partitionnement ----
wipefs -af /dev/nvme0n1
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 1025MiB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script mkpart root btrfs 1025MiB 103425MiB
parted /dev/nvme0n1 --script mkpart home btrfs 103425MiB 100%

# ---- Formatage ----
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2
mkfs.btrfs -f /dev/nvme0n1p3

# ---- Montage ----
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home

# ---- Installation de base ----
pacstrap -K /mnt base linux linux-firmware amd-ucode sudo btrfs-progs grub efibootmgr

# ---- Configuration système ----
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "archMaN" > /etc/hostname

# Réseau
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# GRUB
mkdir -p /boot/EFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Utilisateur
useradd -mG wheel steeve
echo "steeve:changeme" | chpasswd
echo "root:changeme" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Pilotes AMD + Hyprland
pacman -S --noconfirm mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon \
  xf86-video-amdgpu pipewire wireplumber pavucontrol \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  hyprland kitty dolphin thunar wofi \
  qt5-wayland qt6-wayland grim slurp wl-clipboard

# Hyprland config minimale
runuser -l steeve -c 'mkdir -p ~/.config/hypr'
runuser -l steeve -c 'echo -e "[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && exec Hyprland" > ~/.bash_profile'

runuser -l steeve -c 'cat > ~/.config/hypr/hyprland.conf <<EOL
exec-once = kitty

input {
  kb_layout = us
}

monitor=,preferred,auto,1
EOL'

EOF

# ---- Fin ----
umount -R /mnt
echo "✅ Installation terminée. Redémarre avec : reboot"

