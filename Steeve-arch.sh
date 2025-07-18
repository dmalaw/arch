#!/bin/bash
set -e

# Vérifie les privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ce script doit être exécuté en tant que root." >&2
  exit 1
fi

# ---- Clavier fixe : us ----
echo "🔤 Configuration du clavier : us"
loadkeys us

# ---- Vérification Internet ----
echo "🌐 Vérification de la connexion Internet..."
ping -q -c 1 archlinux.org || { echo "❌ Aucune connexion Internet."; exit 1; }

# ---- Miroirs optimisés pour le Canada ----
reflector --country Canada --latest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# ---- Liste des disques ----
echo "💽 Disques disponibles :"
lsblk -d -e7 -o NAME,SIZE
read -rp "👉 Entrez le disque cible (ex: nvme0n1) : " DISK

echo "⚠️ ATTENTION : tout le contenu de /dev/$DISK sera effacé !"
read -rp "Confirmer (yes/no) : " confirm
[ "$confirm" != "yes" ] && { echo "Opération annulée."; exit 1; }

# ---- Partitionnement automatique ----
echo "📦 Partitionnement automatique..."
wipefs -af /dev/"$DISK"
parted -s /dev/"$DISK" mklabel gpt
parted -s /dev/"$DISK" mkpart ESP fat32 1MiB 513MiB
parted -s /dev/"$DISK" set 1 esp on
parted -s /dev/"$DISK" mkpart BOOT ext4 513MiB 1537MiB
parted -s /dev/"$DISK" mkpart SWAP linux-swap 1537MiB 34305MiB
parted -s /dev/"$DISK" mkpart ROOT btrfs 34305MiB 134305MiB
parted -s /dev/"$DISK" mkpart HOME ext4 134305MiB 100%

BOOTPART="/dev/${DISK}p1"
EFIPART="/dev/${DISK}p2"
SWAPPART="/dev/${DISK}p3"
ROOTPART="/dev/${DISK}p4"
HOMEPART="/dev/${DISK}p5"

# ---- Formatage ----
echo "🧹 Formatage des partitions..."
mkfs.fat -F32 "$BOOTPART"
mkfs.ext4 "$EFIPART"
mkswap "$SWAPPART"
swapon "$SWAPPART"
mkfs.btrfs -f "$ROOTPART"
mkfs.ext4 "$HOMEPART"

# ---- Montage ----
echo "📁 Montage des partitions..."
mount "$ROOTPART" /mnt
mkdir -p /mnt/boot /mnt/boot/efi /mnt/home
mount "$EFIPART" /mnt/boot
mount "$BOOTPART" /mnt/boot/efi
mount "$HOMEPART" /mnt/home

# ---- Installation du système de base ----
echo "📦 Installation de base avec Timeshift..."
pacstrap -K /mnt base linux linux-firmware sudo btrfs-progs nano git grub efibootmgr networkmanager timeshift

# ---- fstab ----
genfstab -U /mnt >> /mnt/etc/fstab

# ---- Configuration système dans chroot ----
echo "🚪 Configuration dans le système installé..."
arch-chroot /mnt /bin/bash <<'EOF'

# Fuseau horaire et horloge
ln -sf /usr/share/zoneinfo/America/Toronto /etc/localtime
hwclock --systohc

# Locales
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

# Mot de passe root
echo "🔐 Définir le mot de passe root..."
echo "root:changeme" | chpasswd

# ---- Création utilisateur interactif ----
read -rp "👤 Entrez un nom d'utilisateur : " NEWUSER
useradd -mG wheel -s /bin/bash "$NEWUSER"
echo "$NEWUSER:changeme" | chpasswd
echo "$NEWUSER ALL=(ALL) ALL" | tee /etc/sudoers.d/"$NEWUSER" > /dev/null
chmod 440 /etc/sudoers.d/"$NEWUSER"

# ---- GRUB + hibernation ----
UUID_SWAP=$(blkid -s UUID -o value "$SWAPPART")
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet resume=UUID=$UUID_SWAP\"|" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Activer services
systemctl enable NetworkManager

EOF

# ---- Démontage et fin ----
umount -R /mnt
swapoff "$SWAPPART"
echo "✅ Installation terminée. Redémarrez avec : reboot"