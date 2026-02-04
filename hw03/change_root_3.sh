#!/bin/bash
# удаляем временный lv
lvremove -y /dev/vg_root/lv_root
vgremove -y /dev/vg_root
pvremove -y /dev/vdb
# монтируем /home
lvcreate -n LogVol_Home -L 2G /dev/ubuntu-vg
mkfs.xfs /dev/ubuntu-vg/LogVol_Home
mount /dev/ubuntu-vg/LogVol_Home /mnt/
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/ubuntu-vg/LogVol_Home /home/
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
# создаем снапшот
touch /home/file{1..20}
lvcreate -L 100MB -s -n home_snap /dev/ubuntu-vg/LogVol_Home
rm -f /home/file{11..20}
ls -al /home
# восстанавливаемся со снапшота
umount /home
lvconvert --merge /dev/ubuntu-vg/home_snap
mount /dev/mapper/ubuntu--vg-LogVol_Home /home
ls -al /home