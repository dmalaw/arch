#!/bin/bash
set -e

# === Clavier US + miroir rapide ===
loadkeys us
reflector --country Canada --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# === Partitionnement disque (GPT) ===
wipefs -af /dev/nvme0n1
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 1025MiB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script mkpart root btrfs 1025MiB 103425MiB
parted /dev/nvme0n1 --script mkpart home btrfs 103425MiB 100%

# === Formatage ===
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2
mkfs.btrfs -f /dev/nvme0n1p3

# === Montage des partitions ===
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home

# === Installation du système de base ===
pacstrap -K /mnt base linux linux-firmware amd-ucode sudo btrfs-progs grub efibootmgr greetd greetd-tuigreet bash

# === Fstab + chroot ===
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash <<EOF

# === Configuration système ===
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "archMaN" > /etc/hostname

# === Réseau ===
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# === GRUB ===
mkdir -p /boot/EFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# === Création de l'utilisateur ===
useradd -mG wheel -s /bin/bash steeve
echo "steeve:changeme" | chpasswd
echo "root:changeme" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# === Hyprland + outils ===
pacman -S --noconfirm hyprland \
  kitty dolphin thunar wofi \
  pipewire wireplumber pavucontrol \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  qt5-wayland qt6-wayland grim slurp wl-clipboard \
  mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu

# === greetd PAM ===
cat > /etc/pam.d/greetd <<PAM
auth     include system-local-login
account  include system-local-login
password include system-local-login
session  include system-local-login
PAM

# === Config greetd ===
cat > /etc/greetd/config.toml <<CFG
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd Hyprland --user-menu --remember"
user = "steeve"
CFG

# === Activation greetd, désactivation tty1 ===
systemctl disable getty@tty1
systemctl mask getty@tty1
systemctl enable greetd

# === Config Hyprland minimal ===
runuser -l steeve -c 'mkdir -p ~/.config/hypr'

runuser -l steeve -c 'cat > ~/.config/hypr/hyprland.conf <<EOL
exec-once = kitty

input {
  kb_layout = us
}

monitor=,preferred,auto,1
EOL'

# === Nettoyage (pas de bash_profile) ===
rm -f /home/steeve/.bash_profile

EOF

# === Fin ===
umount -R /mnt
echo "✅ Installation terminée ! Redémarre avec : reboot"
