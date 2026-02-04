#!/bin/bash
# временный lv
pvcreate /dev/vdb
vgcreate vg_root /dev/vdb
lvcreate -n lv_root -l +100%FREE -y /dev/vg_root
mkfs.ext4 /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt
rsync -avxHAX --progress / /mnt/
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/ grub-mkconfig -o /boot/grub/grub.cfg
chroot /mnt/ update-initramfs -u

