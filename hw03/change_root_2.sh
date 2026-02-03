#!/bin/bash

lsblk
lvremove -y /dev/ubuntu-vg/ubuntu-lv
lvcreate -n ubuntu-vg/ubuntu-lv -L 8G -y /dev/ubuntu-vg
mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mount /dev/ubuntu-vg/ubuntu-lv /mnt
rsync -avxHAX --progress / /mnt/
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
cat << EOF | chroot /mnt/
grub-mkconfig -o /boot/grub/grub.cfg
update-initramfs -u
pvcreate /dev/vdc /dev/vdd
vgcreate vg_var /dev/vdc /dev/vdd
lvcreate -L 950M -m1 -n lv_var vg_var
mkfs.ext4 /dev/vg_var/lv_var
mkdir /mnt1
mount /dev/vg_var/lv_var /mnt1
cp -aR /var/* /mnt1/
rm -rf /var/*
umount /mnt1
mount /dev/vg_var/lv_var /var
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
EOF


#reboot
