#!/bin/bash
# Arch install script for Lenovo Flex 14 (AMD)

# Installation guide

#	1 Pre-installation

#		1.1 Verify signature
# Not explicitly necessary for my purposes.

#		1.2 Boot the live environment
# How aren't you booting the live environment?

#		1.3 Set the keyboard layout
loadkeys us

#		1.4 Verify the boot mode
# TODO: Will do later with error checking.

#		1.5 Connect to the internet
# You should have done this already to get this script.

#		1.6 Update the system clock
timedatectl set-ntp true

# Partition scheme:
# /dev/nvme0n1p1	/boot	260MB	FAT32
# /dev/nvme0n1p2	/	35GB	ext4
# /dev/nvme0n1p3	/home	MAX	ext4

#		1.7 Partition the disks
fdisk /dev/nvme0n1 --wipe always <<EOF
g
n
1

+260M
t
1
1
n
2

+35G
t
2
24
n
3


t
3
28
w
EOF

#		1.8 Format the partitions
yes | mkfs.fat -F 32 /dev/nvme0n1p1
yes | mkfs.ext4 /dev/nvme0n1p2
yes | mkfs.ext4 /dev/nvme0n1p3

#		1.9 Mount the file systems
mount /dev/nvme0n1p2 /mnt
mkdir /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home

#	2 Installation

#		2.1 Select the mirrors
pacman -Sy
pacman --sync --noconfirm reflector
reflector --country "United States" --protocol https --fastest 5 --save /etc/pacman.d/mirrorlist

#		2.2 Install essential packages
pacstrap /mnt base base-devel linux linux-firmware exfat-utils connman nano man-db man-pages texinfo amd-ucode

#	3 Configure the system

#		3.1 Fstab
genfstab -U /mnt >> /mnt/etc/fstab

#		3.2 Chroot
# Probably shouldn't be done, scripting across root boundaries is iffy.
# Thankfully we can run individual commands as chroot and immediately back out.

#		3.3 Time zone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc

#		3.4 Localization
sed -i "/^#en_US.UTF-8 UTF-8/ cen_US.UTF-8 UTF-8" /mnt/etc/locale.gen
sed -i "/^#ja_JP.UTF-8 UTF-8/ cja_JP.UTF-8 UTF-8" /mnt/etc/locale.gen
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
# TODO: We'll get to this when I get to Hibernation.

#		3.7 Root password
echo -e "====ROOT PASSWORD====\a"
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
options	root=UUID=`findmnt -rno UUID /mnt/` rw
EOF
mkdir /mnt/etc/pacman.d/hooks
cat >> /mnt/etc/pacman.d/hooks/100-systemd-boot-update.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update 
EOF

#	4 Reboot
# Yeahhhhhh no we're not going to do this.

#	5 Post-installation
# We go to and complete the "General recommendations" page.

# General recommendations

#	1 System administration

#		1.1 Users and groups
arch-chroot /mnt useradd --groups wheel patch
echo -e "====PATCH PASSWORD====\a"
arch-chroot /mnt passwd patch
arch-chroot /mnt useradd --create-home --groups wheel pps3941
echo -e "====PPS3941 PASSWORD====\a"
arch-chroot /mnt passwd pps3941

#		1.2 Privilege elevation
# Needs to be nopasswd so we can install yay. Will get fixed later on in the script.
# TODO: Turn passwords back on.
sed -i "/^# %wheel ALL=(ALL) NOPASSWD: ALL/ c%wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers

#		1.3 Service management
# Irrelevant.

#		1.4 System maintenance
# Irrelevant.

#	2 Package management

#		2.1 pacman
sed -i "/^#Color/ cColor" /mnt/etc/locale.gen
sed -i "/^#TotalDownload/ cTotalDownload" /mnt/etc/locale.gen

#		2.2 Repositories
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
awk -v RS="\0" -v ORS="" '{gsub(/\#\[multilib\]\n\#Include/, "[multilib]\nInclude")}7' /mnt/etc/pacman.conf.bak > /mnt/etc/pacman.conf

#		2.3 Mirrors
cat >> /mnt/etc/systemd/system/reflector.service <<EOF
[Unit]
Description=Pacman mirrorlist update
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector --country "United States" --protocol https --fastest 5 --save /etc/pacman.d/mirrorlist

[Install]
RequiredBy=multi-user.target
EOF
arch-chroot /mnt systemctl enable reflector.service

#		2.4 Arch Build System
# Irrelevant.
#		2.5 Arch User Repository
curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o /mnt/home/pps3941/yay.tar.gz
tar xvf /mnt/home/pps3941/yay.tar.gz -C /mnt/home/pps3941
arch-chroot /mnt chown pps3941:pps3941 /home/pps3941/yay.tar.gz /home/pps3941/yay
arch-chroot /mnt su - pps3941 -c "cd yay && yes | makepkg -si"

#	3 Booting

#		3.1 Hardware auto-recognition
# Irrelevant.

#		3.2 Microcode
# Already taken care of in Installation guide 3.8 - Boot loader. 

#		3.3 Retaining boot messages
# Irrelevant.

#		3.4 Num Lock activation
# Irrelevant.

#	4 Graphical user interface

#		4.1 Display server
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm xorg "

#		4.2 Display drivers
#		4.3 Desktop environments
#		4.4 Window managers
#		4.5 Display manager
#		4.6 User directories
#	5 Power management
#		5.1 ACPI events
#		5.2 CPU frequency scaling
#		5.3 Laptops
#		5.4 Suspend and hibernate
#	6 Multimedia
#		6.1 Sound
#		6.2 Browser plugins
#		6.3 Codecs
#	7 Networking
#		7.1 Clock synchronization
#		7.2 DNS security
#		7.3 Setting up a firewall
#		7.4 Resource sharing
#	8 Input devices
#		8.1 Keyboard layouts
#		8.2 Mouse buttons
#		8.3 Laptop touchpads
#		8.4 TrackPoints
#	9 Optimization
#		9.1 Benchmarking
#		9.2 Improving performance
#		9.3 Solid state drives
#	10 System service
#		10.1 File index and search
#		10.2 Local mail delivery
#		10.3 Printing
#	11 Appearance
#		11.1 Fonts
#		11.2 GTK and Qt themes
#	12 Console improvements
#		12.1 Tab-completion enhancements
#		12.2 Aliases
#		12.3 Alternative shells
#		12.4 Bash additions
#		12.5 Colored output
#		12.6 Compressed files
#		12.7 Console prompt
#		12.8 Emacs shell
#		12.9 Mouse support
#		12.10 Scrollback buffer
#		12.11 Session management
