#!/bin/bash
set -e

DISK="/dev/nvme0n1"
EFI="${DISK}p1"
ROOT="${DISK}p2"

echo "Effacement complet de $DISK"
sgdisk -Z $DISK
echo "Création partitions EFI + ROOT"
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI $DISK
sgdisk -n2:0:0 -t2:8300 -c2:ROOT $DISK

echo "Formatage des partitions"
mkfs.fat -F32 $EFI
mkfs.btrfs -f $ROOT

echo "Création sous-volumes Btrfs"
mount $ROOT /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

echo "Montage des sous-volumes"
mount -o compress=zstd,subvol=@ $ROOT /mnt
mkdir -p /mnt/{boot,home}
mount -o compress=zstd,subvol=@home $ROOT /mnt/home
mount $EFI /mnt/boot

echo "Installation de la base"
pacstrap /mnt base linux linux-firmware

echo "Génération fstab"
genfstab -U /mnt > /mnt/etc/fstab

echo "Fin du script minimal de test."
echo "Tu peux maintenant arch-chroot /mnt pour continuer la configuration."