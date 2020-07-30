#!/bin/bash
# Arch install script for my desktop (AMD)

function fail {
	if [ $1 -eq 1 ]; then
		noncrit
		echo "Critical failure: $2 on line $3. Goodbye."
		exit $1
	else
		echo "Non-critical failure: $2 on line $3. Continuing..."
		if [ -z "$errorlog" ]; then
			errorlog="$2 on line $3"
		else
			errorlog="$errorlog;\n$2 on line $3"
		fi
	fi
}

function noncrit {
	if [ -z "$errorlog" ]; then
		print "No non-critical failures."
	else
		print "Non-critical failures:\n$errorlog."
	fi
}

# Installation guide

# 1 - Pre-installation
# 1.3 - Set the keyboard layout
loadkeys us || fail 2 "failed to change the keyboard layout" $LINENO

# 1.4 - Verify the boot mode
if [ ! -d "/sys/firmware/efi/efivars" ]; then
	fail 1 "booted into BIOS mode" $LINENO
fi

# 1.6 - Update the system clock
timedatectl set-ntp true || fail 2 "failed to update system clock" $LINENO

# 1.7 - Partition the disks
# Partition scheme:
# /dev/sda1	/boot	260MB	FAT32
# /dev/sda2	/	MAX	ext4
# /dev/sdb1	/home	MAX	ext4

fdisk /dev/sda -W always <<EOF || fail 1 "failed to partition sda" $LINENO
g
n
1

+260M
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

fdisk /dev/sdb -W always <<EOF || fail 1 "failed to partition sdb" $LINENO
g
n
1


t
1
28
w
EOF

# 1.8 - Format the partitions
yes | mkfs.fat -F 32 /dev/sda1 || fail 1 "failed to format sda1" $LINENO
yes | mkfs.ext4 /dev/sda2 || fail 1 "failed to format sda2" $LINENO
yes | mkfs.ext4 /dev/sdb1 || fail 1 "failed to format sdb1" $LINENO

# Mount the file systems
mount /dev/sda2 /mnt
mkdir /mnt/boot /mnt/home
mount /dev/sda1 /mnt/boot
mount /dev/sdb1 /mnt/home
fallocate -l 20G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# 2 - Installation
# 2.1 - Select the mirrors
pacman -Sy
pacman -S --noconfirm reflector
reflector -c "United States" -p https -f 5 --save /etc/pacman.d/mirrorlist

# 2.2 - Install essential packages
pacstrap /mnt base base-devel linux linux-firmware exfat-utils networkmanager network-manager-applet nano man-db man-pages texinfo amd-ucode

# 3 - Configure the system
# 3.1 - Fstab
genfstab -U /mnt >> /mnt/etc/fstab

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
hostname="pps3941-desktop"
echo $hostname > /mnt/etc/hostname

cat >> /mnt/etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	$hostname.localdomain	$hostname
EOF

arch-chroot /mnt systemctl disable systemd-networkd.service
arch-chroot /mnt systemctl enable NetworkManager.service

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

cat > /mnt/boot/loader/entries/arch.conf <<EOF
title	Arch Linux
linux	/vmlinuz-linux
initrd	/amd-ucode.img
initrd	/initramfs-linux.img
options	root=UUID=`findmnt -rno UUID /mnt/` resume=`findmnt -rno SOURCE -T /mnt/swapfile` resume_offset=`filefrag -v /mnt/swapfile | awk '{ if($1=="0:"){print $4} }' | sed 's/\.\.//'` rw
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

# General recommendations

# 1 - System administration
# 1.1 - Users and groups
arch-chroot /mnt useradd -m -G wheel patch
echo -e "====PATCH PASSWORD====\a"
arch-chroot /mnt passwd patch
arch-chroot /mnt useradd -m -G wheel pps3941
echo -e "====PPS3941 PASSWORD====\a"
arch-chroot /mnt passwd pps3941
default_user="patch"

# 1.2 - Privilege escalation
# TODO: Turn passwords back on.
sed -i "/^# %wheel ALL=(ALL) NOPASSWD: ALL/ c%wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers

# 2 - Package management
# 2.1 - pacman
sed -i "/^#Color/ cColor" /mnt/etc/pacman.conf
sed -i "/^#TotalDownload/ cTotalDownload" /mnt/etc/pacman.conf

# 2.2 - Repositories
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
awk -v RS="\0" -v ORS="" '{gsub(/#\[multilib\]\n#Include/, "[multilib]\nInclude")}7' /mnt/etc/pacman.conf.bak > /mnt/etc/pacman.conf
arch-chroot /mnt pacman -Sy

# 2.3 - Mirrors
arch-chroot /mnt su - $default_user -c "pacman -S --noconfirm reflector"

cat > /mnt/etc/systemd/system/reflector.service <<EOF
[Unit]
Description=pacman mirrorlist update
Wants=network-online.target
After=network-online.target nss-lookup.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reflector -c "United States" -p https -f 5 --save /etc/pacman.d/mirrorlist

[Install]
RequiredBy=multi-user.target
EOF

arch-chroot /mnt systemctl enable reflector.service

# 2.5 - Arch User Repository
curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o /mnt/home/$default_user/yay.tar.gz
tar xvf /mnt/home/$default_user/yay.tar.gz -C /mnt/home/$default_user
arch-chroot /mnt chown $default_user:$default_user /home/$default_user/yay.tar.gz /home/$default_user/yay
arch-chroot /mnt su - $default_user -c "cd yay && yes | makepkg -si"
rm /mnt/home/$default_user/yay.tar.gz
rm -rf /mnt/home/$default_user/yay

# 4 - Graphical user interface
# 4.1 - Display server
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm xorg"

# 4.2 - Display drivers
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau"

# 4.4 - Window managers
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm openbox obconf obkey tint2 xbindkeys"

# 4.5 - Display manager
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm lightdm lightdm-gtk-greeter"
arch-chroot /mnt systemctl enable lightdm.service

# 4.6 - User directories
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm xdg-user-dirs"
arch-chroot /mnt xdg-user-dirs-update

# 5 - Power management
# 5.1 - ACPI events
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm powerkit"

# 5.2 - CPU frequency scaling
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm tlp"
arch-chroot /mnt systemctl enable tlp.service

# 5.3 - Laptops
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm brightnessctl"

# 5.4 - Suspend and hibernate
sed -i '/^HOOKS=/ s/udev/udev resume/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

# 6 - Multimedia
# 6.1 - Sound
arch-chroot /mnt su - $default_user -c "yay -S --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth pasystray pavucontrol"

# 7 - Networking
# 7.1 - Clock synchronization
arch-chroot /mnt systemctl enable systemd-timesyncd.service

# 8 - Input devices

# 9 - Optimization
# 9.3 - Solid state drives
arch-chroot /mnt systemctl enable fstrim.timer

# 10 - System service

# 11 - Appearance

# 12 - Console improvements

noncrit
