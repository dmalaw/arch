#!/bin/bash
set -e
export TERM=linux
loadkeys us

DISK="nvme0n1"
BOOTPART="/dev/${DISK}p1"    # EFI (FAT32)
EFIPART="/dev/${DISK}p2"     # /boot (ext4)
SWAPPART="/dev/${DISK}p3"    # swap
ROOTPART="/dev/${DISK}p4"    # /
HOMEPART="/dev/${DISK}p5"    # /home

USERNAME="steeve"
PASSWORD="changeme"

echo "🔥 Nettoyage rapide du disque /dev/$DISK..."
sgdisk --zap-all /dev/$DISK
wipefs -af /dev/$DISK

echo "📦 Partitionnement automatique (EFI, boot, swap, root, home)..."
sgdisk -n1:0:+512MiB   -t1:ef00 -c1:"EFI System"   /dev/$DISK
sgdisk -n2:0:+1GiB     -t2:8300 -c2:"Boot"         /dev/$DISK
sgdisk -n3:0:+16GiB    -t3:8200 -c3:"Swap"         /dev/$DISK
sgdisk -n4:0:+100GiB   -t4:8300 -c4:"Root"         /dev/$DISK
sgdisk -n5:0:0         -t5:8300 -c5:"Home"         /dev/$DISK

echo "🧹 Formatage des partitions..."
mkfs.fat -F32 $BOOTPART
mkfs.ext4 $EFIPART
mkswap $SWAPPART
swapon $SWAPPART
mkfs.btrfs -f $ROOTPART
mkfs.ext4 $HOMEPART

echo "📁 Montage dans le bon ordre..."
mount $ROOTPART /mnt
mkdir -p /mnt/boot /mnt/boot/efi /mnt/home
mount $EFIPART /mnt/boot        # /boot = ext4
mount $BOOTPART /mnt/boot/efi   # /boot/efi = FAT32
mount $HOMEPART /mnt/home

echo "📦 Installation du système de base..."
pacstrap -K /mnt base linux linux-firmware sudo btrfs-progs nano git grub efibootmgr networkmanager timeshift

genfstab -U /mnt >> /mnt/etc/fstab

echo "⚙️ Configuration système dans chroot..."
arch-chroot /mnt /bin/bash <<'EOF'

# Configuration locale
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Hostname
echo "archMaN" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archMaN.localdomain archMaN
HOSTS

# Utilisateur + root
echo "root:changeme" | chpasswd
useradd -mG wheel -s /bin/bash steeve
echo "steeve:changeme" | chpasswd
echo "steeve ALL=(ALL) ALL" > /etc/sudoers.d/steeve
chmod 440 /etc/sudoers.d/steeve

# GRUB + hibernation
UUID_SWAP=$(blkid -s UUID -o value /dev/nvme0n1p3)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet resume=UUID=$UUID_SWAP\"|" /etc/default/grub

# Vérifie que /boot/efi est bien monté
if ! findmnt -rno SOURCE,TARGET /boot/efi >/dev/null; then
  echo "❌ /boot/efi n'est pas monté ! GRUB ne peut pas s'installer."
  exit 1
fi

# Installation GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Réseau
systemctl enable NetworkManager

EOF

echo "📸 Snapshot Timeshift post-install..."
mount $ROOTPART /mnt
arch-chroot /mnt timeshift --create --comments "Post-install Arch" --tags D
umount -R /mnt
swapoff $SWAPPART

echo "✅ Installation Arch terminée avec succès."
echo "➡️ Utilisateur : steeve / changeme"
echo "💡 Tape : reboot"