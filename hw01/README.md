># Цель домашнего задания:

## Научиться обновлять ядро в ОС Linux.

>Описание домашнего задания:

1) Запустить ВМ c Ubuntu.
2) Обновить ядро ОС на новейшую стабильную версию из mainline-репозитория.
3) Оформить отчет в README-файле в GitHub-репозитории.


Перед работами проверим текущую версию ядра:

```console
$ uname -a

Linux host1 6.8.0-94-generic #96-Ubuntu SMP PREEMPT_DYNAMIC Fri Jan  9 20:36:55 UTC 2026 x86_64 x86_64 x86_64 GNU/Linu
```

```console
$ cat /etc/*release

DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="Ubuntu 24.04.3 LTS"
PRETTY_NAME="Ubuntu 24.04.3 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.3 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo
```
Находим актуальную ссылку и качаем пакеты на виртуальную машину:

```console
$ mkdir kernel && cd kernel
$ wget https://kernel.ubuntu.com/mainline/v6.18.7/amd64/linux-headers-6.18.7-061807-generic_6.18.7-061807.202601231045_amd64.deb
$ wget https://kernel.ubuntu.com/mainline/v6.18.7/amd64/linux-headers-6.18.7-061807_6.18.7-061807.202601231045_all.deb
$ wget https://kernel.ubuntu.com/mainline/v6.18.7/amd64/linux-image-unsigned-6.18.7-061807-generic_6.18.7-061807.202601231045_amd64.deb
$ wget https://kernel.ubuntu.com/mainline/v6.18.7/amd64/linux-modules-6.18.7-061807-generic_6.18.7-061807.202601231045_amd64.deb
```
Устанавливаем все пакеты сразу:

```console
$ sudo dpkg -i *.deb 
```

Проверяем, что ядро появилось в /boot:

```console
$ ls -al /boot

-rw-r--r--  1 root root   303931 Jan 23 10:45 config-6.18.7-061807-generic
-rw-r--r--  1 root root   287562 Jan 17  2025 config-6.8.0-53-generic
-rw-r--r--  1 root root   287416 Jan  9 16:07 config-6.8.0-94-generic
drwxr-xr-x  5 root root     4096 Jan 31 09:42 grub
lrwxrwxrwx  1 root root       32 Jan 31 09:42 initrd.img -> initrd.img-6.18.7-061807-generic
-rw-r--r--  1 root root 50803577 Jan 31 09:42 initrd.img-6.18.7-061807-generic
-rw-r--r--  1 root root 48073842 Jan 31 07:41 initrd.img-6.8.0-53-generic
-rw-r--r--  1 root root 48039495 Jan 31 07:42 initrd.img-6.8.0-94-generic
lrwxrwxrwx  1 root root       27 Jan 31 09:42 initrd.img.old -> initrd.img-6.8.0-94-generic
drwx------  2 root root    16384 Feb 20  2025 lost+found
-rw-------  1 root root 11451473 Jan 23 10:45 System.map-6.18.7-061807-generic
-rw-------  1 root root  9080742 Jan 17  2025 System.map-6.8.0-53-generic
-rw-------  1 root root  9114947 Jan  9 16:07 System.map-6.8.0-94-generic
lrwxrwxrwx  1 root root       29 Jan 31 09:42 vmlinuz -> vmlinuz-6.18.7-061807-generic
-rw-------  1 root root 17252544 Jan 23 10:45 vmlinuz-6.18.7-061807-generic
-rw-------  1 root root 14981512 Jan 17  2025 vmlinuz-6.8.0-53-generic
-rw-------  1 root root 15001992 Jan  9 17:37 vmlinuz-6.8.0-94-generic
lrwxrwxrwx  1 root root       24 Jan 31 09:42 vmlinuz.old -> vmlinuz-6.8.0-94-generic
```

Обновляем конфигурацию загрузчика:

```console
$ sudo update-grub
$ sudo grub-set-default 0
```

После перезагрузки снова проверяем версию ядра:

```console
$ uname -a

Linux host1 6.18.7-061807-generic #202601231045 SMP PREEMPT_DYNAMIC Fri Jan 23 11:25:00 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
```


># Дополнительное задание:

## Собрать ядро самостоятельно из исходных кодов.


Добавляем “deb-src” в строку Types: в /etc/apt/sources.list.d/ubuntu.sources файле:

```console
Types: deb deb-src
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Устанавливаем необходимые пакеты:

```console
$ sudo apt update && \
    sudo apt build-dep -y linux linux-image-unsigned-$(uname -r) && \
    sudo apt install -y fakeroot llvm libncurses-dev dwarves
```

Получаем исходный код ядра:

```console
$ apt source linux-image-unsigned-$(uname -r)
```

Подготовка исходного кода ядра:

```console
$ cd linux-6.8.0
$ chmod a+x debian/scripts/* && \
    chmod a+x debian/scripts/misc/* && \
    fakeroot debian/rules clean
```

Изменяем ABI номер (9999) в файле debian.master/changelog:

```console
linux (6.8.0-9999.96) noble; urgency=medium
```

Изменяем конфигурацию ядра:

```console
$ fakeroot debian/rules editconfigs
```

Компилируем ядро:

```console
$ fakeroot debian/rules clean && \
    fakeroot debian/rules binary

виртуалка зависла при компиляции, переделывать не стал
```

Установка ядра:

```console
$ sudo dpkg -i *.deb
```

Перезагрузка:

```console
$ uname -a


