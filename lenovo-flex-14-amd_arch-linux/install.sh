#!/bin/bash
# Arch install script for Lenovo Flex 14 (AMD)

#	1 Pre-installation
#		1.1 Verify signature
#		1.2 Boot the live environment
#		1.3 Set the keyboard layout
loadkeys us
#		1.4 Verify the boot mode
#		1.5 Connect to the internet
#		1.6 Update the system clock
timedatectl set-ntp true
#		1.7 Partition the disks
sfdisk --force /dev/nvme0n1 < partitions
#		1.8 Format the partitions
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkfs.ext4 /dev/nvme0n1p3
#		1.9 Mount the file systems
mount /dev/nvme0n1p2 /mnt
mkdir /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home
#	2 Installation
#		2.1 Select the mirrors
pacman -S reflector
reflector --country --protocol https --fastest 5
#		2.2 Install essential packages
pacstrap /mnt base base-devel linux linux-firmware exfat-utils connman nano man-db man-pages texinfo
#	3 Configure the system
#		3.1 Fstab
genfstab -U /mnt >> /mnt/etc/fstab
#		3.2 Chroot
#		3.3 Time zone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc
#		3.4 Localization
sed -i "/^#en_US.UTF-8/ cen_US.UTF-8" /mnt/etc/locale.gen
sed -i "/^#ja_JP.UTF-8/ cja_JP.UTF-8" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf
#		3.5 Network configuration
echo "pps3941-laptop" > /mnt/etc/hostname
cat >> /mnt/etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	pps3941-laptop.localdomain	pps3941-laptop
EOF
#		3.6 Initramfs
#		3.7 Root password
echo -n "Enter root password: "
arch-chroot /mnt passwd
#		3.8 Boot loader
arch-chroot /mnt bootctl install
cat >> /mnt/boot/loader/loader.conf <<EOF
default	arch.conf
timeout	1
editor	no
EOF
cat >> /mnt/boot/loader/entries/arch.conf <<EOF
title	Arch Linux
linux	/vmlinuz-linux
initrd	/amd-ucode.img
initrd	/initramfs-linux.img
options	root=[] rw
EOF
#	4 Reboot
#	5 Post-installation
