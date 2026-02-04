>## Цель домашнего задания:

## Работа с LVM-RAID.

>## Описание домашнего задания:

1) Уменьшить том под / до 8G.
2) Выделить том под /home.
3) Выделить том под /var - сделать в mirror.
4) /home - сделать том для снапшотов.
5) Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами (на выбор).
6) Работа со снапшотами:
   a. сгенерить файлы в /home/;
   b. снять снапшот;
   c. удалить часть файлов;
   d. восстановится со снапшота.
7) На дисках попробовать поставить btrfs/zfs — с кэшем, снапшотами и разметить там каталог /opt.




Добавляем 4 диска по 10G:

```console
M = 4
(1..M).each do |j|
   libvirt.storage :file, :size => '10G'
end
```

```console
$ sudo lsblk
NAME                      MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda                       253:0    0  64G  0 disk 
├─vda1                    253:1    0   1M  0 part 
├─vda2                    253:2    0   2G  0 part /boot
└─vda3                    253:3    0  62G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0  31G  0 lvm  /
vdb                       253:16   0  10G  0 disk 
vdc                       253:32   0  10G  0 disk 
vdd                       253:48   0  10G  0 disk 
vde                       253:64   0  10G  0 disk 
```
Подготовим временный том для / раздела (change_root_1.sh):

```console
$ sudo ./change_root_1.sh
$ sudo reboot
$ sudo lsblk

vda                       253:0    0  64G  0 disk 
├─vda1                    253:1    0   1M  0 part 
├─vda2                    253:2    0   2G  0 part /boot
└─vda3                    253:3    0  62G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:1    0  31G  0 lvm  
vdb                       253:16   0  10G  0 disk 
└─vg_root-lv_root         252:0    0  10G  0 lvm  /
vdc                       253:32   0  10G  0 disk 
vdd                       253:48   0  10G  0 disk 
vde                       253:64   0  10G  0 disk 
```
Создаем новые / и /var разделы (change_root_2.sh):

```console
$ sudo ./change_root_2.sh
$ sudo reboot
$ sudo lsblk

vda                       253:0    0   64G  0 disk 
├─vda1                    253:1    0    1M  0 part 
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   62G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:6    0    8G  0 lvm  /
vdb                       253:16   0   10G  0 disk 
└─vg_root-lv_root         252:0    0   10G  0 lvm  
vdc                       253:32   0   10G  0 disk 
├─vg_var-lv_var_rmeta_0   252:1    0    4M  0 lvm  
│ └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0  252:2    0  952M  0 lvm  
  └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
vdd                       253:48   0   10G  0 disk 
├─vg_var-lv_var_rmeta_1   252:3    0    4M  0 lvm  
│ └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1  252:4    0  952M  0 lvm  
  └─vg_var-lv_var         252:5    0  952M  0 lvm  /var
vde                       253:64   0   10G  0 disk 
```

Создаем новый /home и работаем со снапшотами(change_root_3.sh):

```console
$ sudo ./change_root_3.sh

  Logical volume "lv_root" successfully removed.
  Volume group "vg_root" successfully removed
  Labels on physical volume "/dev/vdb" successfully wiped.
  Logical volume "LogVol_Home" created.
meta-data=/dev/ubuntu-vg/LogVol_Home isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
         =                       reflink=1    bigtime=1 inobtcount=1 nrext64=0
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=16384, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
  Logical volume "home_snap" created.
total 4
drwxr-xr-x  3 root    root     152 Feb  4 03:43 .
drwxr-xr-x 24 root    root    4096 Feb  4 03:25 ..
-rw-r--r--  1 root    root       0 Feb  4 03:43 file1
-rw-r--r--  1 root    root       0 Feb  4 03:43 file10
-rw-r--r--  1 root    root       0 Feb  4 03:43 file2
-rw-r--r--  1 root    root       0 Feb  4 03:43 file3
-rw-r--r--  1 root    root       0 Feb  4 03:43 file4
-rw-r--r--  1 root    root       0 Feb  4 03:43 file5
-rw-r--r--  1 root    root       0 Feb  4 03:43 file6
-rw-r--r--  1 root    root       0 Feb  4 03:43 file7
-rw-r--r--  1 root    root       0 Feb  4 03:43 file8
-rw-r--r--  1 root    root       0 Feb  4 03:43 file9
drwxr-x---  4 vagrant vagrant  168 Feb  4 03:30 vagrant
  Merging of volume ubuntu-vg/home_snap started.
  ubuntu-vg/LogVol_Home: Merged: 100.00%
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
total 4
drwxr-xr-x  3 root    root     292 Feb  4 03:43 .
drwxr-xr-x 24 root    root    4096 Feb  4 03:25 ..
-rw-r--r--  1 root    root       0 Feb  4 03:43 file1
-rw-r--r--  1 root    root       0 Feb  4 03:43 file10
-rw-r--r--  1 root    root       0 Feb  4 03:43 file11
-rw-r--r--  1 root    root       0 Feb  4 03:43 file12
-rw-r--r--  1 root    root       0 Feb  4 03:43 file13
-rw-r--r--  1 root    root       0 Feb  4 03:43 file14
-rw-r--r--  1 root    root       0 Feb  4 03:43 file15
-rw-r--r--  1 root    root       0 Feb  4 03:43 file16
-rw-r--r--  1 root    root       0 Feb  4 03:43 file17
-rw-r--r--  1 root    root       0 Feb  4 03:43 file18
-rw-r--r--  1 root    root       0 Feb  4 03:43 file19
-rw-r--r--  1 root    root       0 Feb  4 03:43 file2
-rw-r--r--  1 root    root       0 Feb  4 03:43 file20
-rw-r--r--  1 root    root       0 Feb  4 03:43 file3
-rw-r--r--  1 root    root       0 Feb  4 03:43 file4
-rw-r--r--  1 root    root       0 Feb  4 03:43 file5
-rw-r--r--  1 root    root       0 Feb  4 03:43 file6
-rw-r--r--  1 root    root       0 Feb  4 03:43 file7
-rw-r--r--  1 root    root       0 Feb  4 03:43 file8
-rw-r--r--  1 root    root       0 Feb  4 03:43 file9
drwxr-x---  4 vagrant vagrant  168 Feb  4 03:30 vagrant


$ sudo lsblk

vda                        253:0    0   64G  0 disk 
├─vda1                     253:1    0    1M  0 part 
├─vda2                     253:2    0    2G  0 part /boot
└─vda3                     253:3    0   62G  0 part 
  ├─ubuntu--vg-LogVol_Home 252:0    0    2G  0 lvm  /home
  └─ubuntu--vg-ubuntu--lv  252:6    0    8G  0 lvm  /
vdb                        253:16   0   10G  0 disk 
vdc                        253:32   0   10G  0 disk 
├─vg_var-lv_var_rmeta_0    252:1    0    4M  0 lvm  
│ └─vg_var-lv_var          252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   252:2    0  952M  0 lvm  
  └─vg_var-lv_var          252:5    0  952M  0 lvm  /var
vdd                        253:48   0   10G  0 disk 
├─vg_var-lv_var_rmeta_1    252:3    0    4M  0 lvm  
│ └─vg_var-lv_var          252:5    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   252:4    0  952M  0 lvm  
  └─vg_var-lv_var          252:5    0  952M  0 lvm  /var
vde                        253:64   0   10G  0 disk 

