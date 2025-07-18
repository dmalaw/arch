#!/bin/bash
set -e

### VARIABLES
DISK="/dev/nvme0n1"
EFI="${DISK}p1"
ROOT="${DISK}p2"
USERNAME="steeve"
HOSTNAME="archMaN"
LOCALE="en_CA.UTF-8"
KEYMAP="us"
SLEEP_MINUTES="10"

### TEMPORARY KEYMAP
loadkeys us

### CONFIRMATION
read -p "⚠️ Ce script efface entièrement $DISK (nvme0n1). Continuer ? (o/N) " confirm
[[ $confirm != "o" ]] && echo "Installation annulée." && exit 1

### PARTITIONNEMENT
sgdisk -Z $DISK
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI $DISK
sgdisk -n2:0:0      -t2:8300 -c2:ROOT $DISK

### FORMATAGE
mkfs.fat -F32 $EFI
mkfs.btrfs -f $ROOT

### CRÉATION DES SOUS-VOLUMES
mount $ROOT /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

### MONTAGE DES VOLUMES
mount -o compress=zstd,subvol=@ $ROOT /mnt
mkdir -p /mnt/{boot,home}
mount -o compress=zstd,subvol=@home $ROOT /mnt/home
mount $EFI /mnt/boot

### INSTALLATION DE BASE
pacstrap -K /mnt base linux linux-firmware amd-ucode btrfs-progs \
  networkmanager vim nano sudo git neofetch \
  mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu \
  systemd-boot

### FSTAB
genfstab -U /mnt >> /mnt/etc/fstab

### CHROOT CONFIGURATION
arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOL
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOL

### UTILISATEUR
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:arch" | chpasswd
echo "root:arch" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

### SYSTEMD-BOOT
bootctl install
UUID=\$(blkid -s UUID -o value $ROOT)

cat > /boot/loader/loader.conf <<EOL
default arch
timeout 3
editor no
EOL

cat > /boot/loader/entries/arch.conf <<EOL
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=\$UUID rw rootflags=subvol=@ quiet splash
EOL

### ACTIVER SERVICES
systemctl enable NetworkManager
systemctl enable systemd-logind.service

### CONFIG SLEEP AUTO
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/sleep.conf <<EOL
[Login]
IdleAction=suspend
IdleActionSec=${SLEEP_MINUTES}min
EOL

EOF

### FIN
echo -e "\n✅ Installation complète sur $DISK (nvme0n1)"
echo "➡️ Pour finaliser :"
echo "arch-chroot /mnt    # Si tu veux personnaliser"
echo "Puis :"
echo "exit && umount -R /mnt && reboot"