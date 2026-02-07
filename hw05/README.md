>## Цель домашнего задания:

## Научиться самостоятельно разворачивать сервис NFS и подключать к нему клиентов.

>## Описание домашнего задания:

Основная часть: 
- запустить 2 виртуальных машины (сервер NFS и клиента);
- на сервере NFS должна быть подготовлена и экспортирована директория; 
- в экспортированной директории должна быть поддиректория с именем upload с правами на запись в неё; 
- экспортированная директория должна автоматически монтироваться на клиенте при старте виртуальной машины (systemd, autofs или fstab — любым способом);
- монтирование и работа NFS на клиенте должна быть организована с использованием NFSv3.

Для самостоятельной реализации: 
- настроить аутентификацию через KERBEROS с использованием NFSv4.



Развертываем окружение ([Vagrantfile](https://github.com/slako68/Otus.Linux.Professional/tree/main/hw05/Vagrantfile)):

```console
$ vagrant up

ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|

  IP1 = "192.168.122.101"
  IP2 = "192.168.122.102"

  config.vm.define "nfss" do |node|
    node.vm.box = "bento/ubuntu-24.04"
    node.vm.hostname = "nfss"
    node.vm.network "private_network", ip: "#{IP1}"
    node.vm.provider :libvirt do |libvirt|
      libvirt.cpus = "1"
      libvirt.memory = "1024"
    end
    node.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt install nfs-kernel-server -y
    mkdir -p /srv/share/upload
    chown -R nobody:nogroup /srv/share
    chmod 0777 /srv/share/upload
    echo "/srv/share #{IP2}/32(rw,sync,root_squash)" > /etc/exports 
    reboot
    SHELL
  end

    config.vm.define "nfsc" do |node|
    node.vm.box = "bento/ubuntu-24.04"
    node.vm.hostname = "nfsc"
    node.vm.network "private_network", ip: "#{IP2}"
    node.vm.provider :libvirt do |libvirt|
      libvirt.cpus = "1"
      libvirt.memory = "1024"
    end
    node.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt install nfs-common -y
    echo "#{IP1}:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
    reboot
    SHELL
  end

end
```

## Настраиваем сервер NFS 


Установим сервер NFS:

```console
# apt install nfs-kernel-server
```

Создаём и настраиваем директорию, которая будет экспортирована:

```console
# mkdir -p /srv/share/upload
# chown -R nobody:nogroup /srv/share
# chmod 0777 /srv/share/upload
# cat /etc/exports
/srv/share 192.168.122.102/32(rw,sync,root_squash)
# exportfs -r
# exportfs -s
/srv/share  192.168.122.102/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

## Настраиваем клиент NFS 

```console
# apt install nfs-common
# echo "192.168.122.101:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
# systemctl daemon-reload
# systemctl restart remote-fs.target
# mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=73,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=17432)
192.168.122.101:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.122.101,mountvers=3,mountport=40634,mountproto=udp,local_lock=none,addr=192.168.122.101)
```
```console
$ ls -l /mnt/upload
total 0
-rw-r--r-- 1 root    root    0 Feb  7 03:22 check_file
-rw-rw-r-- 1 vagrant vagrant 0 Feb  7 03:22 client_file
-rw-rw-r-- 1 vagrant vagrant 0 Feb  7 03:30 final_check
```

## Автоматизация развертывания

Команды развертывания сервера и клинета включены в секцию provision [Vagrantfile](https://github.com/slako68/Otus.Linux.Professional/tree/main/hw05/Vagrantfile):

```
    node.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt install nfs-kernel-server -y
    mkdir -p /srv/share/upload
    chown -R nobody:nogroup /srv/share
    chmod 0777 /srv/share/upload
    echo "/srv/share #{IP2}/32(rw,sync,root_squash)" > /etc/exports 
    reboot
    SHELL
```
```
    node.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt install nfs-common -y
    echo "#{IP1}:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab
    reboot
    SHELL
```