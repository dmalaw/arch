#!/bin/bash
set -e

# Clavier
loadkeys us

# Variables
DISK="nvme0n1"
BOOTPART="/dev/${DISK}p1"
EFIPART="/dev/${DISK}p2"
SWAPPART="/dev/${DISK}p3"
ROOTPART="/dev/${DISK}p4"
HOMEPART="/dev/${DISK}p5"

USERNAME="steeve"
PASSWORD="changeme"

echo "📦 Partitionnement du disque /dev/$DISK..."
wipefs -af /dev/$DISK
parted -s /dev/$DISK mklabel gpt
parted -s /dev/$DISK mkpart ESP fat32 1MiB 513MiB
parted -s /dev/$DISK set 1 esp on
parted -s /dev/$DISK mkpart BOOT ext4 513MiB 1537MiB
parted -s /dev/$DISK mkpart SWAP linux-swap 1537MiB 17537MiB
parted -s /dev/$DISK mkpart ROOT btrfs 17537MiB 117537MiB
parted -s /dev/$DISK mkpart HOME ext4 117537MiB 100%

echo "🧹 Formatage..."
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $EFIPART
mkswap $SWAPPART
swapon $SWAPPART
mkfs.btrfs -f $ROOTPART
mkfs.ext4 $HOMEPART

echo "📁 Montage..."
mount $ROOTPART /mnt
mkdir -p /mnt/boot/efi /mnt/boot /mnt/home
mount $EFIPART /mnt/boot
mount $BOOTPART /mnt/boot/efi
mount $HOMEPART /mnt/home

echo "📦 Installation base + grub + timeshift..."
pacstrap -K /mnt base linux linux-firmware sudo btrfs-progs grub efibootmgr networkmanager nano git timeshift

genfstab -U /mnt >> /mnt/etc/fstab

echo "🚪 Chroot et configuration..."
arch-chroot /mnt /bin/bash <<EOF

ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

echo "archMaN" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archMaN.localdomain archMaN
HOSTS

# Utilisateur root
echo "root:$PASSWORD" | chpasswd

# Utilisateur $USERNAME
useradd -mG wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# GRUB + hibernation
UUID_SWAP=\$(blkid -s UUID -o value $SWAPPART)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet resume=UUID=\$UUID_SWAP\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Activer NetworkManager
systemctl enable NetworkManager
EOF

# Snapshot timeshift automatique
echo "📸 Création d’un snapshot timeshift initial..."
mount $ROOTPART /mnt
arch-chroot /mnt timeshift --create --comments "Initial Post-Install Snapshot" --tags D
umount -R /mnt
swapoff $SWAPPART

echo "✅ Installation terminée. Tu peux redémarrer."