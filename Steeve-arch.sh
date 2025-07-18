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

echo "🔥 Nettoyage complet du disque /dev/$DISK..."
sgdisk --zap-all /dev/nvme0n1
wipefs -a /dev/nvme0n1

echo "📦 Partitionnement automatique (EFI, boot, swap, root, home)..."
sgdisk -n1:1MiB:513MiB       -t1:ef00 -c1:"EFI System"   /dev/$DISK
sgdisk -n2:513MiB:1537MiB    -t2:8300 -c2:"Boot"         /dev/$DISK
sgdisk -n3:1537MiB:17537MiB  -t3:8200 -c3:"Swap"         /dev/$DISK
sgdisk -n4:17537MiB:117537MiB -t4:8300 -c4:"Root"        /dev/$DISK
sgdisk -n5:117537MiB:0       -t5:8300 -c5:"Home"         /dev/$DISK

echo "🧹 Formatage des partitions..."
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $EFIPART
mkswap $SWAPPART
swapon $SWAPPART
mkfs.btrfs -f $ROOTPART
mkfs.ext4 $HOMEPART

echo "📁 Montage..."
mount $ROOTPART /mnt
mkdir -p /mnt/boot/efi /mnt/home
mount $EFIPART /mnt/boot/efi
mount $BOOTPART /mnt/boot
mount $HOMEPART /mnt/home

echo "📦 Installation du système de base..."
pacstrap -K /mnt base linux linux-firmware sudo btrfs-progs nano git grub efibootmgr networkmanager timeshift

genfstab -U /mnt >> /mnt/etc/fstab

echo "⚙️ Configuration chroot..."
arch-chroot /mnt /bin/bash <<EOF

# Localisation
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

# Comptes
echo "root:$PASSWORD" | chpasswd
useradd -mG wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# GRUB + hibernation
UUID_SWAP=\$(blkid -s UUID -o value $SWAPPART)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet resume=UUID=\$UUID_SWAP\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager

EOF

echo "📸 Création snapshot Timeshift..."
mount $ROOTPART /mnt
arch-chroot /mnt timeshift --create --comments "Post-install Arch" --tags D
umount -R /mnt
swapoff $SWAPPART

echo "✅ Installation Arch terminée sans aucune interaction."
echo "➡️ Utilisateur : steeve | Mot de passe : changeme"
echo "💡 Tape 'reboot' pour démarrer le système installé."