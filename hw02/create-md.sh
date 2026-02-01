#! /bin/bash

mdadm --zero-superblock --force /dev/vd{b,c,d,e,f}             # зануляем суперблоки
mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/vd{b,c,d,e}  # создаем рейд
mdadm /dev/md0 --add /dev/vdf                                  # добавляем hot-spare
cat /proc/mdstat
mdadm -D /dev/md0

parted -s /dev/md0 mklabel gpt                                 # создаем разделы
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%
for i in $(seq 1 5); do mkfs.ext4 /dev/md0p$i; done            # создаем файловые системы
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done   # монтируем
df -hT

