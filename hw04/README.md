>## Цель домашнего задания:

## ZFS.

>## Описание домашнего задания:

1. Определить алгоритм с наилучшим сжатием:
2. Определить какие алгоритмы сжатия поддерживает zfs (gzip, zle, lzjb, lz4);
   * создать 4 файловых системы на каждой применить свой алгоритм сжатия;
   * для сжатия использовать либо текстовый файл, либо группу файлов.
3. Определить настройки пула.
4. С помощью команды zfs import собрать pool ZFS.
5. Командами zfs определить настройки:
    - размер хранилища;
    - тип pool;
    - значение recordsize;
    - какое сжатие используется;
    - какая контрольная сумма используется.
6. Работа со снапшотами:
   * скопировать файл из удаленной директории;
   * восстановить файл локально. zfs receive;
   * найти зашифрованное сообщение в файле secret_message.


Развертываем окружение (Vagrantfile):

```console
ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'
Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "host#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "host#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "4"
        libvirt.memory = "8192"
          M = 8
          (1..M).each do |j|
            libvirt.storage :file, :size => '512M'
          end
      end
      node.vm.provision "shell", inline: <<-SHELL
      apt-get update
      DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' upgrade
      DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' dist-upgrade
      apt-get autoremove -y
      apt-get clean
      apt-get autoclean
      reboot
      SHELL
    end
  end
end
```

## Определение алгоритма с наилучшим сжатием

Устанавливаем ZFS:

```console
$ sudo apt install zfsutils-linux
```

Создаём пулы из двух дисков в режиме RAID 1:

```console
$ sudo zpool create otus1 mirror /dev/vdb /dev/vdc
$ sudo zpool create otus2 mirror /dev/vdd /dev/vde
$ sudo zpool create otus3 mirror /dev/vdf /dev/vdg
$ sudo zpool create otus4 mirror /dev/vdh /dev/vdi
```

```console
$ sudo zpool list

NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   480M   110K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus2   480M   110K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus3   480M   110K   480M        -         -     0%     0%  1.00x    ONLINE  -
otus4   480M   132K   480M        -         -     0%     0%  1.00x    ONLINE  -
```
Добавим разные алгоритмы сжатия в каждую файловую систему:

```console
$ sudo zfs set compression=lzjb otus1
$ sudo zfs set compression=lz4 otus2
$ sudo zfs set compression=gzip-9 otus3
$ sudo zfs set compression=zle otus4

$ sudo zfs get all | grep compression

otus1  compression           lzjb                   local
otus2  compression           lz4                    local
otus3  compression           gzip-9                 local
otus4  compression           zle                    local
```

Алгоритм gzip-9 самый эффективный:
```console
$ zfs list

NAME    USED  AVAIL  REFER  MOUNTPOINT
otus1  21.7M   330M  21.6M  /otus1
otus2  17.7M   334M  17.6M  /otus2
otus3  10.9M   341M  10.7M  /otus3
otus4  39.5M   313M  39.4M  /otus4

$ zfs get all | grep compressratio | grep -v ref

otus1  compressratio         1.82x                  -
otus2  compressratio         2.23x                  -
otus3  compressratio         3.66x                  -
otus4  compressratio         1.00x                  -
```