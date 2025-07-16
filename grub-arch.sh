#!/bin/bash

# Vérifie que le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en tant que root."
  exit 1
fi

# Configurer la disposition du clavier en US
loadkeys us

# Étape 1 : Vérifier la connexion Internet
echo "Vérification de la connexion Internet..."
ping -c 4 archlinux.org
if [ $? -ne 0 ]; then
  echo "Pas de connexion Internet. Configurez le réseau (wifi-menu ou dhcpcd) et réessayez."
  exit 1
fi

# Étape 2 : Mettre à jour l'horloge système
timedatectl set-ntp true

# Étape 3 : Partitionner le disque NVMe (1 To)
# - 512 Mo pour EFI (/boot/efi)
# - 1 Go pour /boot
# - 32 Go pour swap (adapté pour 32 Go de RAM avec hibernation)
# - 100 Go pour la racine (/)
# - Reste (~867 Go) pour /home
echo "Partitionnement du disque NVMe (/dev/nvme0n1)..."
parted -s /dev/nvme0n1 mklabel gpt
parted -s /dev/nvme0n1 mkpart primary fat32 1MiB 513MiB
parted -s /dev/nvme0n1 set 1 esp on
parted -s /dev/nvme0n1 mkpart primary ext4 513MiB 1537MiB
parted -s /dev/nvme0n1 mkpart primary linux-swap 1537MiB 34305MiB
parted -s /dev/nvme0n1 mkpart primary 34305MiB 134305MiB
parted -s /dev/nvme0n1 mkpart primary ext4 134305MiB 100%

# Étape 4 : Formater les partitions
echo "Formatage des partitions..."
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3
mkfs.btrfs /dev/nvme0n1p4
mkfs.ext4 /dev/nvme0n1p5

# Étape 5 : Monter les partitions
echo "Montage des partitions..."
mount /dev/nvme0n1p4 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p2 /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
mkdir -p /mnt/home
mount /dev/nvme0n1p5 /mnt/home

# Étape 6 : Installer le système de base
echo "Installation du système de base..."
pacstrap /mnt base linux linux-firmware btrfs-progs sudo

# Étape 7 : Générer le fstab
echo "Génération du fichier fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Étape 8 : Chroot dans le nouveau système
echo "Chroot dans le nouveau système..."
arch-chroot /mnt /bin/bash <<EOF

# Configurer le fuseau horaire
ln -sf /usr/share/zoneinfo/America/Montreal /etc/localtime
hwclock --systohc

# Configurer la localisation
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

# Configurer le nom d'hôte
echo "archMaN" > /etc/hostname
cat <<HOSTS > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archMaN.localdomain archMaN
HOSTS

# Configurer le mot de passe root
echo "Définir le mot de passe root..."
passwd

# Créer l'utilisateur Steeve
useradd -m -G wheel steeve
echo "Définir le mot de passe pour Steeve..."
passwd steeve

# Configurer sudo pour l'utilisateur Steeve
echo "steeve ALL=(ALL) ALL" >> /etc/sudoers.d/steeve

# Installer et configurer GRUB
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Installer un gestionnaire de réseau
pacman -S --noconfirm networkmanager
systemctl enable NetworkManager

# Activer la prise en charge de l'hibernation
echo "resume=UUID=$(blkid -s UUID -o value /dev/nvme0n1p3)" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Quitter le chroot
exit
EOF

# Étape 9 : Démonter les partitions et redémarrer
echo "Démontage des partitions..."
umount -R /mnt
swapoff /dev/nvme0n1p3
echo "Installation terminée ! Redémarrage..."
reboot