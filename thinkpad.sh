#!/bin/bash
# Arch install script for my desktop (AMD)

set -e
trap 'echo "An error has occurred on line $LINENO. Exiting script."' ERR

# These variables aren't actually here for customization, they're for eliminating "magic numbers" and the like.
# I simply think here is the best place to put them in case I shuffle around any sections; visibility and such.
# You should read the entire script if you're looking to customize them.
# Well, at least read the parts you are interested in changing.
# This is for personal use by me, so I'm not going to waste my whole life making a perfectly flexible script.
hostname="pps3941-laptop"
default_user="pps3941"

# Installation guide

# 1 - Pre-installation
# "1.1 - Acquire an installation image" through "1.4 - Boot the live environment" are skipped.
# It is assumed that you've already done them to get to this point.

# 1.5 - Set the keyboard layout
loadkeys us

# 1.6 - Verify the boot mode
# This doesn't strictly check, however since we have set a trap, if ls errors then the program will terminate.
ls /sys/firmware/efi/efivars

# "1.7 - Connect to the internet" is skipped as it is assumed that you've already done it to get to this point.
# More specifically, since this script is for myself, I'd prefer to clone the repo from the internet after booting.

# 1.8 - Update the system clock
timedatectl set-ntp true

# 1.9 - Partition the disks
# Partition scheme:
# /dev/sda1	/boot	512MB	FAT32
# /dev/sda2	/	MAX	ext4

fdisk /dev/sda -W always <<EOF
g
n
1

+512M
n
2


t
1
1
t
2
24
w
EOF

# 1.10 - Format the partitions
yes | mkfs.fat -F 32 /dev/sda1
yes | mkfs.ext4 /dev/sda2

# 1.11 - Mount the file systems
mount /dev/sda2 /mnt
mkdir /mnt/boot /mnt/home
mount /dev/sda1 /mnt/boot

# Swapfile stuff?
# TODO: Examine if this needs to go in the block where I set up resume/hibernate.

fallocate -l 10G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# 2 - Installation
# 2.1 - Select the mirrors
# TODO: remove magic phrase here
reflector -c "United States" -p https -f 5 --sort rate --save /etc/pacman.d/mirrorlist'

# 2.2 - Install essential packages
pacstrap /mnt base base-devel linux linux-zen linux-firmware networkmanager network-manager-applet nano man-db man-pages tldr texinfo intel-ucode

# 3 - Configure the system
# 3.1 - Fstab
genfstab -U /mnt >> /mnt/etc/fstab

# "3.2 - Chroot" is skipped as it is incorporated in every command necessary.

# 3.3 - Time zone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc

# 3.4 - Localization
sed -i "/^#en_US.UTF-8 UTF-8/ cen_US.UTF-8 UTF-8" /mnt/etc/locale.gen
sed -i "/^#ja_JP.UTF-8 UTF-8/ cja_JP.UTF-8 UTF-8" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

# 3.5 - Network configuration
echo "$hostname" > /mnt/etc/hostname

cat >> /mnt/etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname
EOF

arch-chroot /mnt systemctl disable systemd-networkd.service
arch-chroot /mnt systemctl enable NetworkManager.service

# "3.6 - Initramfs" is skipped as it is not necessary at this point in time.

# 3.7 - Root password
echo -e "====ROOT PASSWORD====\a"
arch-chroot /mnt passwd

# 3.8 - Boot loader
arch-chroot /mnt bootctl install

cat > /mnt/boot/loader/loader.conf <<EOF
default	arch.conf
timeout	1
editor	no
EOF

# Please note that I have preemptively added resume stuff because holy hell would that be annoying to edit later.
# Sidenote,
# TODO: Fix that so that resume/hibernate is handled in its own block, correctly.

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title	Arch Linux
linux	/vmlinuz-linux
initrd	/intel-ucode.img
initrd	/initramfs-linux.img
options	root=UUID=`findmnt -rno UUID /mnt/` resume=`findmnt -rno SOURCE -T /mnt/swapfile` resume_offset=`filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' | sed 's/\.\.//'` rw
EOF

cat > /mnt/boot/loader/entries/arch-zen.conf <<EOF
title	Arch Linux (Zen)
linux	/vmlinuz-linux-zen
initrd	/intel-ucode.img
initrd	/initramfs-linux-zen.img
options	root=UUID=`findmnt -rno UUID /mnt/` resume=`findmnt -rno SOURCE -T /mnt/swapfile` resume_offset=`filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' | sed 's/\.\.//'` rw
EOF

mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/100-systemd-boot-update.hook <<EOF
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Updating systemd-boot
When = PostTransaction
Exec = /usr/bin/bootctl update
EOF

# "4 - Reboot" is skipped for obvious reasons.
# "5 - Post-installation" is the next section of the script.

### END OF PAGE ###

# General recommendations

# 1 - System administration
# 1.1 - Users and groups
arch-chroot /mnt useradd -m -G wheel patch
echo -e "====PATCH PASSWORD====\a"
arch-chroot /mnt passwd patch
arch-chroot /mnt useradd -m -G wheel pps3941
echo -e "====PPS3941 PASSWORD====\a"
arch-chroot /mnt passwd pps3941

# 1.2 - Privilege escalation
sed -i "/^# %wheel ALL=(ALL) NOPASSWD: ALL/ c%wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers

# "1.3 - Service management" and "1.4 - System maintenance" are skipped as they are merely educational.

# 2 - Package management
# 2.1 - pacman
sed -i "/^#Color/ cColor" /mnt/etc/pacman.conf
sed -i "/^#TotalDownload/ cTotalDownload" /mnt/etc/pacman.conf

# 2.2 - Repositories
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
awk -v RS="\0" -v ORS="" '{gsub(/#\[multilib\]\n#Include/, "[multilib]\nInclude")}7' /mnt/etc/pacman.conf.bak > /mnt/etc/pacman.conf
rm /mnt/etc/pacman.conf.bak
arch-chroot /mnt pacman -Sy

# 2.3 - Mirrors
arch-chroot /mnt su - "$default_user" -c "pacman -S --noconfirm reflector"

# TODO: remove magic phrase here
cat >> /etc/xdg/reflector/reflector.conf <<EOF
-c "United States"
-p https
-f 5
--sort rate
--save /etc/pacman.d/mirrorlist
EOF

arch-chroot /mnt systemctl enable reflector.timer

# "2.4 - Arch Build System" is skipped as it is merely educational.

# 2.5 - Arch User Repository
curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o /mnt/home/"$default_user"/yay.tar.gz
tar xvf /mnt/home/"$default_user"/yay.tar.gz -C /mnt/home/"$default_user"
arch-chroot /mnt chown "$default_user":"$default_user" /home/"$default_user"/yay.tar.gz /home/"$default_user"/yay
arch-chroot /mnt su - "$default_user" -c "cd yay && yes | makepkg -si"
rm /mnt/home/"$default_user"/yay.tar.gz
rm -rf /mnt/home/"$default_user"/yay

# "3 - Booting" and all its subsections are skipped as they are already implemented or irrelevant.

# 4 - Graphical user interface
# 4.1 - Display server
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm xorg"

# 4.2 - Display drivers
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel intel-media-driver lib32-intel-media-driver libva-intel-driver lib32-libva-intel-driver mesa-vdpau lib32-mesa-vdpau"

# "4.3 - Desktop environments" is skipped as it is irrelevant.

# 4.4 - Window managers
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm openbox obconf obkey tint2"

# 4.5 - Display manager
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm lightdm lightdm-gtk-greeter"
arch-chroot /mnt systemctl enable lightdm.service

# 4.6 - User directories
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm xdg-user-dirs"
arch-chroot /mnt xdg-user-dirs-update

# 5 - Power management
# 5.1 - ACPI events
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm powerkit"

# 5.2 - CPU frequency scaling
#arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm tlp"
#arch-chroot /mnt systemctl enable tlp.service

# 5.3 - Laptops
#arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm brightnessctl"

# 5.4 - Suspend and hibernate
# TODO: Move all hibernate-related code in here. This'll be annoying...
sed -i '/^HOOKS=/ s/udev/udev resume/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

# 6 - Multimedia
# 6.1 - Sound
arch-chroot /mnt su - "$default_user" -c "yay -S --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth pasystray pavucontrol"

# 7 - Networking
# 7.1 - Clock synchronization
arch-chroot /mnt systemctl enable systemd-timesyncd.service

# TODO - The rest of the document.

# 9 - Optimization
# 9.3 - Solid state drives
#arch-chroot /mnt systemctl enable fstrim.timer

### END OF PAGE ###
### MAINTENANCE ###

# 1.2 - Privilege escalation, part 2
sed -i "/^%wheel ALL=(ALL) NOPASSWD: ALL/ c# %wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers
sed -i "/^# %wheel ALL=(ALL) ALL/ c%wheel ALL=(ALL) ALL" /mnt/etc/sudoers
