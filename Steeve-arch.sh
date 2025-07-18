#!/bin/bash
set -e
export TERM=linux
loadkeys us

DISK="nvme0n1"
BOOTPART="/dev/${DISK}p1"
EFIPART="/dev/${DISK}p2"
SWAPPART="/dev/${DISK}p3"
ROOTPART="/dev/${DISK}p4"
HOMEPART="/dev/${DISK}p5"

USERNAME="steeve"
PASSWORD="changeme"

echo "🧹 Suppression des anciennes partitions sur /dev/$DISK..."
sgdisk --zap-all /dev/$DISK
wipefs -af /dev/$DISK

echo "📦 Partitionnement automatique..."
parted -s -f /dev/$DISK mklabel gpt
parted -s -f /dev/$DISK mkpart ESP fat32 1MiB 513MiB
parted -s -f /dev/$DISK set 1 esp on
parted -s -f /dev/$DISK mkpart BOOT ext4 513MiB 1537MiB
parted -s -f /dev/$DISK mkpart SWAP linux-swap 1537MiB 17537MiB
parted -s -f /dev/$DISK mkpart ROOT btrfs 17537MiB 117537MiB
parted -s -f /dev/$DISK mkpart HOME ext4 117537MiB 100%

echo "🧹 Formatage des partitions..."
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $EFIPART
mkswap $SWAPPART
swapon $SWAPPART
mkfs.btrfs -f $ROOTPART
mkfs.ext4 $HOMEPART

echo "📁 Montage des partitions..."
mount $ROOTPART /mnt
mkdir -p /mnt/boot/efi
mkdir -p /mnt/home
mount $EFIPART /mnt/boot/efi
mount $BOOTPART /mnt/boot
mount $HOMEPART /mnt/home

echo "📦 Installation du système de base..."
pacstrap -K /mnt base linux linux-firmware sudo btrfs-progs nano git grub efibootmgr networkmanager timeshift

genfstab -U /mnt >> /mnt/etc/fstab

echo "🚪 Chroot et configuration système..."
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

echo "root:$PASSWORD" | chpasswd

useradd -mG wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

UUID_SWAP=\$(blkid -s UUID -o value $SWAPPART)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet resume=UUID=\$UUID_SWAP\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
EOF

echo "📸 Snapshot Timeshift post-install..."
mount $ROOTPART /mnt
arch-chroot /mnt timeshift --create --comments "Post-install Arch" --tags D
umount -R /mnt
swapoff $SWAPPART

echo "✅ Installation Arch terminée avec succès !"
echo "➡️ Utilisateur : steeve / Mot de passe : changeme"
echo "💡 Tu peux redémarrer avec : reboot"
