># Цель домашнего задания:

## Работа с mdadm.

>Описание домашнего задания:

1) Добавить в виртуальную машину несколько дисков
2) Собрать RAID-0/1/5/10 на выбор
3) Сломать и починить RAID
4) Создать GPT таблицу, пять разделов и смонтировать их в системе.



Добавляем 5 дисков (вносим изменения в Vagrantfile):

```console
M = 5
(1..M).each do |j|
   libvirt.storage :file, :size => '1G'
end
```

```console
$ sudo lshw -short | grep disk

/0/100/3/0    /dev/vda   disk           68GB Virtual I/O device
/0/100/4/0    /dev/vdb   disk           1073MB Virtual I/O device
/0/100/5/0    /dev/vdc   disk           1073MB Virtual I/O device
/0/100/6/0    /dev/vdd   disk           1073MB Virtual I/O device
/0/100/7/0    /dev/vde   disk           1073MB Virtual I/O device
/0/100/8/0    /dev/vdf   disk           1073MB Virtual I/O device
```
Скрипт для создания рейда, GPT, файловых систем и монтирования:

```
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
```
Запускаем скрипт:

```console
$ sudo ./create-md.sh

mdadm: Unrecognised md component device - /dev/vdb
mdadm: Unrecognised md component device - /dev/vdc
mdadm: Unrecognised md component device - /dev/vdd
mdadm: Unrecognised md component device - /dev/vde
mdadm: Unrecognised md component device - /dev/vdf
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 1046528K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
mdadm: added /dev/vdf
Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] [raid10] 
md0 : active raid10 vdf[4](S) vde[3] vdd[2] vdc[1] vdb[0]
      2093056 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
      [>....................]  resync =  1.6% (33792/2093056) finish=1.0min speed=33792K/sec
      
unused devices: <none>
/dev/md0:
           Version : 1.2
     Creation Time : Sun Feb  1 08:22:16 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Feb  1 08:22:16 2026
             State : clean, resyncing 
    Active Devices : 4
   Working Devices : 5
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

     Resync Status : 1% complete

              Name : host1:0  (local to host host1)
              UUID : aefd07ea:6ac0ba88:48d24526:cd74a593
            Events : 1

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync set-A   /dev/vdb
       1     253       32        1      active sync set-B   /dev/vdc
       2     253       48        2      active sync set-A   /dev/vdd
       3     253       64        3      active sync set-B   /dev/vde

       4     253       80        -      spare   /dev/vdf
Information: You may need to update /etc/fstab.

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.                           

Information: You may need to update /etc/fstab.                           

mke2fs 1.47.0 (5-Feb-2023)                                                
Discarding device blocks: done                            
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 4438654a-a4ce-4497-9960-05bceed3c257
Superblock backups stored on blocks: 
	32768, 98304

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 104704 4k blocks and 104704 inodes
Filesystem UUID: bc2dd579-bca9-42b2-95fe-739d8be3aa88
Superblock backups stored on blocks: 
	32768, 98304

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 2d8ca257-a702-47a1-8a3b-ca248598b9fc
Superblock backups stored on blocks: 
	32768, 98304

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 104704 4k blocks and 104704 inodes
Filesystem UUID: 28b43c6d-8111-4380-8830-0fed3cf0c86f
Superblock backups stored on blocks: 
	32768, 98304

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 104448 4k blocks and 104448 inodes
Filesystem UUID: 710d446a-90b1-4922-a83a-46a1fa194476
Superblock backups stored on blocks: 
	32768, 98304

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

Filesystem                        Type   Size  Used Avail Use% Mounted on
tmpfs                             tmpfs   97M  1.0M   96M   2% /run
/dev/mapper/ubuntu--vg-ubuntu--lv ext4    31G  4.6G   25G  16% /
tmpfs                             tmpfs  481M     0  481M   0% /dev/shm
tmpfs                             tmpfs  5.0M     0  5.0M   0% /run/lock
/dev/vda2                         ext4   2.0G  146M  1.7G   8% /boot
tmpfs                             tmpfs   97M   12K   97M   1% /run/user/1000
/dev/md0p1                        ext4   366M   24K  338M   1% /raid/part1
/dev/md0p2                        ext4   367M   24K  339M   1% /raid/part2
/dev/md0p3                        ext4   366M   24K  338M   1% /raid/part3
/dev/md0p4                        ext4   367M   24K  339M   1% /raid/part4
/dev/md0p5                        ext4   366M   24K  338M   1% /raid/part5
```

Осталось сломать рейд (используется hot-spare):

```console
$ sudo mdadm /dev/md0 --fail /dev/vdd

/dev/md0:
           Version : 1.2
     Creation Time : Sun Feb  1 08:22:16 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 5
       Persistence : Superblock is persistent

       Update Time : Sun Feb  1 08:42:41 2026
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : host1:0  (local to host host1)
              UUID : aefd07ea:6ac0ba88:48d24526:cd74a593
            Events : 53

    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync set-A   /dev/vdb
       1     253       32        1      active sync set-B   /dev/vdc
       4     253       80        2      active sync set-A   /dev/vdf
       3     253       64        3      active sync set-B   /dev/vde

       2     253       48        -      faulty   /dev/vdd
```

Удаляем сбойный диск и добавляем hot-spare:

```console
$ sudo mdadm /dev/md0 --remove /dev/vdd
$ sudo mdadm /dev/md0 --add /dev/vdd


    Number   Major   Minor   RaidDevice State
       0     253       16        0      active sync set-A   /dev/vdb
       1     253       32        1      active sync set-B   /dev/vdc
       4     253       80        2      active sync set-A   /dev/vdf
       3     253       64        3      active sync set-B   /dev/vde

       5     253       48        -      spare   /dev/vdd
```

