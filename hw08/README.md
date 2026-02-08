>## Цель домашнего задания:

## Инициализация системы. Systemd .

>## Описание домашнего задания:

1) Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/default).
2) Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта (https://gist.github.com/cea2k/1318020).
3) Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.


Развертываем окружение:

```console
$ vagrant up

ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'
Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "host#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "host#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "1"
        libvirt.memory = "1024"
      end
      node.vm.provision "shell", inline: <<-SHELL
      apt-get update
      SHELL
    end
  end
end
```

## Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова

Создаём файл с конфигурацией для сервисаКомментируем строку, скрывающую меню и ставим задержку:

```console
$ sudo vi /etc/default/watchlog

# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```

Создаем скрипт:


```console
$ sudo vi  /opt/watchlog.sh

#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi

$ sudo chmod +x /opt/watchlog.sh
```

Создаем юнит для сервиса:

```console
$ sudo vi /etc/systemd/system/watchlog.service

[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

Создаем юнит для таймера:

```console
$ sudo vi /etc/systemd/system/watchlog.timer

[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```

Запускаем таймер:

```console
$ sudo systemctl status watchlog.service
$ sudo systemctl start watchlog.timer
$ tail -f /var/log/syslog  | grep word

2026-02-08T09:19:39.074856+00:00 vagrant root: Sun Feb  8 09:19:39 AM UTC 2026: I found word, Master!
2026-02-08T09:20:24.231144+00:00 vagrant root: Sun Feb  8 09:20:24 AM UTC 2026: I found word, Master!
2026-02-08T09:21:49.076446+00:00 vagrant root: Sun Feb  8 09:21:49 AM UTC 2026: I found word, Master!
2026-02-08T09:22:39.075792+00:00 vagrant root: Sun Feb  8 09:22:39 AM UTC 2026: I found word, Master!
```

## Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) 

Устанавливаем spawn-fcgi и необходимые для него пакеты:

```console
$ sudo apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y
```

Файл с настройками:

```console
$ sudo mkdir  /etc/spawn-fcgi
$ sudo vi  /etc/spawn-fcgi/fcgi.conf

# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

Юнит-файл:

```console
$ sudo vi /etc/systemd/system/spawn-fcgi.service

[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

Запускаем:

```console
$ sudo systemctl start spawn-fcgi
$ sudo systemctl status spawn-fcgi
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-02-08 09:47:57 UTC; 6s ago
   Main PID: 11909 (php-cgi)
      Tasks: 33 (limit: 1066)
     Memory: 14.7M (peak: 15.0M)
        CPU: 41ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─11909 /usr/bin/php-cgi
 
```

## Доработать unit-файл Nginx (nginx.service) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно

Установим Nginx из стандартного репозитория:

```console
$ sudo apt install nginx -y
```

Модифицируем исходный service:

```console
$ sudo vi /etc/systemd/system/nginx@.service

# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```

Создаем два файла конфигурации:

```console
$ sudo vi /etc/nginx/nginx-first.conf

pid /run/nginx-first.pid;

http {
…
	server {
		listen 9001;
	}
#include /etc/nginx/sites-enabled/*;
….
}



$ sudo vi /etc/nginx/nginx-second.conf

pid /run/nginx-second.pid;

http {
…
	server {
		listen 9002;
	}
#include /etc/nginx/sites-enabled/*;
….
}
```

Запускаем сервисы:

```console
$ sudo systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-02-08 10:13:08 UTC; 9s ago
       Docs: man:nginx(8)
    Process: 12585 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 12587 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 12588 (nginx)
      Tasks: 2 (limit: 1066)
     Memory: 1.7M (peak: 1.9M)
        CPU: 14ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─12588 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             └─12590 "nginx: worker process"


$ sudo systemctl status nginx@second
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sun 2026-02-08 10:15:21 UTC; 7s ago
       Docs: man:nginx(8)
    Process: 12618 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 12623 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 12625 (nginx)
      Tasks: 2 (limit: 1066)
     Memory: 1.7M (peak: 1.9M)
        CPU: 13ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─12625 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             └─12626 "nginx: worker process"

Feb 08 10:15:21 host1 systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
Feb 08 10:15:21 host1 systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.


$ sudo ss -tnulp | grep nginx
tcp   LISTEN 0      511                0.0.0.0:9002      0.0.0.0:*    users:(("nginx",pid=12626,fd=5),("nginx",pid=12625,fd=5))
tcp   LISTEN 0      511                0.0.0.0:9001      0.0.0.0:*    users:(("nginx",pid=12590,fd=5),("nginx",pid=12588,fd=5))
```