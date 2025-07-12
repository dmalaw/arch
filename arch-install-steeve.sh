#!/bin/bash
set -e

# === Clavier US et miroir ===
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

# === Montage ===
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home

# === Base + grub + greetd (à l'extérieur du chroot) ===
pacstrap -K /mnt base linux linux-firmware amd-ucode sudo btrfs-progs grub efibootmgr greetd greetd-tuigreet bash git

# === Fstab et chroot ===
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash <<EOF

# === Système de base ===
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

# === Utilisateur steeve ===
useradd -mG wheel -s /bin/bash steeve
echo "steeve:changeme" | chpasswd
echo "root:changeme" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# === Installation de Hyprland et Wayland complet ===
pacman -S --noconfirm hyprland \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  kitty dolphin thunar wofi \
  pipewire wireplumber pavucontrol \
  qt5-wayland qt6-wayland \
  grim slurp wl-clipboard \
  mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu

# === Configuration PAM pour greetd ===
cat > /etc/pam.d/greetd <<PAM
auth     include system-local-login
account  include system-local-login
password include system-local-login
session  include system-local-login
PAM

# === Configuration greetd ===
cat > /etc/greetd/config.toml <<CFG
[terminal]
vt = 1

[default_session]
command = "tuigreet --cmd Hyprland --user-menu --remember"
user = "steeve"
CFG

# === Activer greetd, désactiver tty1 ===
systemctl disable getty@tty1
systemctl mask getty@tty1
systemctl enable greetd

# === Supprimer bash_profile inutile ===
rm -f /home/steeve/.bash_profile

# === Config Hyprland pour steeve ===
runuser -l steeve -c 'mkdir -p ~/.config/hypr'
runuser -l steeve -c 'cat > ~/.config/hypr/hyprland.conf <<EOL
exec-once = kitty

input {
  kb_layout = us
}

monitor=,preferred,auto,1
EOL'

EOF

# === Fin d'installation ===
umount -R /mnt
echo "✅ Installation terminée avec greetd + Hyprland. Redémarre avec : reboot"
