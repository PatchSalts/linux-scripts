#!/bin/bash
# Arch install script for Lenovo Flex 14 (AMD)

loadkeys us

# TODO: Verify boot mode later with error checking.

timedatectl set-ntp true

# Partition scheme:
# /dev/nvme0n1p1	/boot	260MB	FAT32
# /dev/nvme0n1p2	/	35GB	ext4
# /dev/nvme0n1p3	/home	MAX	ext4

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

yes | mkfs.fat -F 32 /dev/nvme0n1p1
yes | mkfs.ext4 /dev/nvme0n1p2
yes | mkfs.ext4 /dev/nvme0n1p3

mount /dev/nvme0n1p2 /mnt
mkdir /mnt/boot /mnt/home
mount /dev/nvme0n1p1 /mnt/boot
mount /dev/nvme0n1p3 /mnt/home
fallocate -l 15G /mnt/swapfile
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

pacman -Sy
pacman --sync --noconfirm reflector
reflector --country "United States" --protocol https --fastest 5 --save /etc/pacman.d/mirrorlist

pacstrap /mnt base base-devel linux linux-firmware exfat-utils connman wpa_supplicant cmst nano man-db man-pages texinfo amd-ucode

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
arch-chroot /mnt hwclock --systohc

sed -i "/^#en_US.UTF-8 UTF-8/ cen_US.UTF-8 UTF-8" /mnt/etc/locale.gen
sed -i "/^#ja_JP.UTF-8 UTF-8/ cja_JP.UTF-8 UTF-8" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

echo "pps3941-laptop" > /mnt/etc/hostname

cat >> /mnt/etc/hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.1.1	pps3941-laptop.localdomain	pps3941-laptop
EOF

arch-chroot /mnt systemctl enable connman

echo -e "====ROOT PASSWORD====\a"
arch-chroot /mnt passwd

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

arch-chroot /mnt useradd --create-home --groups wheel patch
echo -e "====PATCH PASSWORD====\a"
arch-chroot /mnt passwd patch
arch-chroot /mnt useradd --create-home --groups wheel pps3941
echo -e "====PPS3941 PASSWORD====\a"
arch-chroot /mnt passwd pps3941

# TODO: Turn passwords back on.
sed -i "/^# %wheel ALL=(ALL) NOPASSWD: ALL/ c%wheel ALL=(ALL) NOPASSWD: ALL" /mnt/etc/sudoers

sed -i "/^#Color/ cColor" /mnt/etc/locale.gen
sed -i "/^#TotalDownload/ cTotalDownload" /mnt/etc/locale.gen

mv /mnt/etc/pacman.conf /mnt/etc/pacman.conf.bak
awk -v RS="\0" -v ORS="" '{gsub(/#\[multilib\]\n#Include/, "[multilib]\nInclude")}7' /mnt/etc/pacman.conf.bak > /mnt/etc/pacman.conf
arch-chroot /mnt pacman --sync --refresh

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

curl https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz -o /mnt/home/pps3941/yay.tar.gz
tar xvf /mnt/home/pps3941/yay.tar.gz -C /mnt/home/pps3941
arch-chroot /mnt chown pps3941:pps3941 /home/pps3941/yay.tar.gz /home/pps3941/yay
arch-chroot /mnt su - pps3941 -c "cd yay && yes | makepkg -si"
rm /mnt/home/pps3941/yay.tar.gz
rm -rf /mnt/home/pps3941/yay

arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm xorg"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon libva-mesa-driver lib32-libva-mesa-driver mesa-vdpau lib32-mesa-vdpau"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm lxqt oxygen-icons noto-fonts noto-fonts-cjk noto-fonts-emoji noto-fonts-extra"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm sddm"

arch-chroot /mnt systemctl enable sddm

arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm xdg-user-dirs"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm tlp"

arch-chroot /mnt systemctl enable tlp

sed -i '/^HOOKS=/ s/udev/udev resume/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -P

arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm pulseaudio pulseaudio-alsa pulseaudio-bluetooth"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm firefox flashplugin"
arch-chroot /mnt su - pps3941 -c "yay --sync --noconfirm chrony"

arch-chroot /mnt systemctl enable chronyd
arch-chroot /mnt systemctl enable fstrim.timer

# TODO: A bunch of stuff in the Laptops article.
