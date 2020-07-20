#!/bin/bash
# Arch install script for my desktop (AMD)

# Installation guide

# 1 - Pre-installation
# 1.3 - Set the keyboard layout
loadkeys us

# 1.4 - Verify the boot mode
if [ -f "/sys/firmware/efi/efivars" ]; then
	echo "Booted into UEFI mode."
else
	echo "Booted into BIOS mode. Exiting..."
	exit 1
fi

# 1.6 - Update the system clock
timedatectl set-ntp true

# 1.7 - Partition the disks
# Partition scheme:
# /dev/sda1	/boot	260MB	FAT32
# /dev/sda2	/	MAX	ext4
# /dev/sdb1	/home	MAX	ext4

fdisk /dev/sda --wipe always <<EOF
g
n
1

+260M
t
1
1
n
2


t
2
24
w
EOF

fdisk /dev/sdb --wipe always <<EOF
g
n
1


t
1
28
w
EOF

# 1.8 - Format the partitions
yes | mkfs.fat -F 32 /dev/sda1
yes | mkfs.ext4 /dev/sda2
yes | mkfs.ext4 /dev/sdb1

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
pacman --sync --noconfirm reflector
reflector --country "United States" --protocol https --fastest 5 --save /etc/pacman.d/mirrorlist

# 2.2 - Install essential packages
pacstrap /mnt base base-devel linux linux-firmware exfat-utils networkmanager network-manger-applet nano man-db man-pages texinfo amd-ucode

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

#arch-chroot /mnt systemctl disable .service
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

# General recommendations

# 1 - System administration
# 1.1 - Users and groups
arch-chroot /mnt useradd --create-home --groups wheel patch
echo -e "====PATCH PASSWORD====\a"
arch-chroot /mnt passwd patch
arch-chroot /mnt useradd --create-home --groups wheel pps3941
echo -e "====PPS3941 PASSWORD====\a"
arch-chroot /mnt passwd pps3941

# 1.2 - Privilege escalation
# TODO: Turn passwords back on.
sed -i "/^# %wheel ALL=(ALL) NOPASSWD: ALL/ c%wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers

# 2 - Package management
# 2.1 - pacman
################################################################################

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

sed -i '/^HOOKS=/ s/udev/udev resume/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

sed -i "/^#Color/ cColor" /mnt/etc/pacman.conf
sed -i "/^#TotalDownload/ cTotalDownload" /mnt/etc/pacman.conf
mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
awk -v RS="\0" -v ORS="" '{gsub(/#\[multilib\]\n#Include/, "[multilib]\nInclude")}7' /mnt/etc/pacman.conf.bak > /mnt/etc/pacman.conf
arch-chroot /mnt pacman --sync --refresh

curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o /mnt/home/patch/yay.tar.gz
tar xvf /mnt/home/patch/yay.tar.gz -C /mnt/home/patch
arch-chroot /mnt chown patch:patch /home/patch/yay.tar.gz /home/patch/yay
arch-chroot /mnt su - patch -c "cd yay && yes | makepkg -si"
rm /mnt/home/patch/yay.tar.gz
rm -rf /mnt/home/patch/yay

arch-chroot /mnt su - patch -c "yay --sync --noconfirm xorg"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm lightdm lightdm-gtk-greeter openbox obconf obkey tint2 rofi terminator tmux pcmanfm notepadqq gimp gimp-plugin-gmic inkscape bomiaudacity puddletag exfalso qpdfview libreoffice calibre firefox flashplugin qbittorrent"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm xdg-user-dirs"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm firefox flashplugin"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm chrony"
arch-chroot /mnt su - patch -c "yay --sync --noconfirm reflector"

cat > /mnt/etc/systemd/system/reflector.service <<EOF
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
arch-chroot /mnt systemctl enable sddm
#arch-chroot /mnt systemctl enable tlp
arch-chroot /mnt systemctl enable chronyd
arch-chroot /mnt systemctl enable fstrim.timer

# TODO: A bunch of stuff in the Laptops article.
