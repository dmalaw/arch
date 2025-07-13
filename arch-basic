#!/bin/bash
set -e

# 1. Clavier et miroirs
loadkeys us
reflector --country Canada --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# 2. Efface le disque et partitionne
wipefs -af /dev/nvme0n1
parted /dev/nvme0n1 --script mklabel gpt
parted /dev/nvme0n1 --script mkpart ESP fat32 1MiB 1025MiB
parted /dev/nvme0n1 --script set 1 esp on
parted /dev/nvme0n1 --script mkpart root btrfs 1025MiB 103425MiB
parted /dev/nvme0n1 --script mkpart home btrfs 103425MiB 100%

# 3. Formater les partitions
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.btrfs -f /dev/nvme0n1p2
mkfs.btrfs -f /dev/nvme0n1p3

# 4. Monter
mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home

# 5. Installer base + timeshift
pacstrap -K /mnt base linux linux-firmware amd-ucode sudo btrfs-progs grub efibootmgr bash nano git networkmanager timeshift

# 6. Générer fstab
genfstab -U /mnt >> /mnt/etc/fstab

# 7. Chroot et configuration système
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
echo "archMaN" > /etc/hostname
systemctl enable NetworkManager

# 8. Installer et configurer GRUB
mkdir -p /boot/EFI
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# 9. Créer utilisateur steeve avec sudo
useradd -mG wheel -s /bin/bash steeve
echo "steeve:changeme" | chpasswd
echo "root:changeme" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
EOF

# 10. Fin
umount -R /mnt
echo "✅ Installation terminée. Tapez 'reboot' pour redémarrer."
