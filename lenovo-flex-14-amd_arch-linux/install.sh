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
#	3 Configure the system
#		3.1 Fstab
#		3.2 Chroot
#		3.3 Time zone
#		3.4 Localization
#		3.5 Network configuration
#		3.6 Initramfs
#		3.7 Root password
#		3.8 Boot loader
#	4 Reboot
#	5 Post-installation

