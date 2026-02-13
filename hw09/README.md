>## Цель домашнего задания:

## написать bash-скрипт, который ежечасно формирует и отправляет на email отчёт о работе веб-сервера.

>## Описание домашнего задания:

Отчёт должен содержать:

IP-адреса с наибольшим числом запросов (с момента последнего запуска);
Запрашиваемые URL с наибольшим числом запросов (с момента последнего запуска);
Ошибки веб-сервера/приложения (с момента последнего запуска);
HTTP-коды ответов с указанием их количества (с момента последнего запуска).

Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.

В письме должен быть прописан обрабатываемый временной диапазон.

## Развертываем окружение:

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
          M = 0
          (1..M).each do |j|
            libvirt.storage :file, :size => '512M'
          end
      end
      node.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt install nginx -y
      apt install mailutils -y
      SHELL
    end
  end
end
```

## Скрипт

```console
#!/bin/bash
 
IFS=" "
PIDFILE=/tmp/script.pid
ACCESSLOG=/var/log/nginx/access.log
ERRORLOG=/var/log/nginx/error.log
EMAIL="$USER@localhost"
EMAIL_CLIENT=/usr/sbin/sendmail
COUNT=10
HOURS=0
ACCDATE="`date --date="$HOURS hours ago" +"%d/%b/%Y:%H"`"
ERRDATE="`date --date="$HOURS hours ago" +"%Y/%m/%d %H"`"

send_mail()
{
        (
cat - <<END
Subject: Last $HOURS hours nginx report.

IP:
 ${IP[@]}

URL:
 ${URL[@]}

STATUS:
 ${STATUS[@]}

ERRORS:
${ERRORS[@]}

END
) | $EMAIL_CLIENT $1
}

if [ -e $PIDFILE ]
then
    exit 1
else
        echo "$$" > $PIDFILE
        trap 'rm -f $PIDFILE; exit $?' INT TERM EXIT
        IP+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $1}' | sort | uniq -c | sort -nr | head -$COUNT`)
        URL+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $7}' | sort | uniq -c | sort -nr | head -$COUNT`)
        STATUS+=(`cat $ACCESSLOG | grep "$ACCDATE" | awk '{print $9}' | sort | uniq -c | sort -nr`)
        ERRORS+=(`cat $ERRORLOG | grep "$ERRDATE"`)
        if [ -e $EMAIL_CLIENT ]
        then
            send_mail $EMAIL
        fi
        rm -r $PIDFILE
        trap - INT TERM EXIT
fi
```

## Почтовое сообщение

```console
vagrant@host1:~$ mailx
"/var/mail/vagrant": 1 message 1 new
>N   1 vagrant            Fri Feb 13 11:39  26/542   Last 1 hours nginx report.
? 1
Return-Path: <vagrant@host1>
X-Original-To: vagrant@localhost
Delivered-To: vagrant@localhost
Received: by host1 (Postfix, from userid 1000)
	id CAE57181052; Fri, 13 Feb 2026 11:39:06 +0000 (UTC)
Subject: Last 1 hours nginx report.
Message-Id: <20260213113906.CAE57181052@host1>
Date: Fri, 13 Feb 2026 11:39:06 +0000 (UTC)
From: vagrant <vagrant@host1>

IP:
 21 127.0.0.1

URL:
 8 /gagadgagaeghadffhadh
 7 /
 5 /gagadgag
 1 /gagadg

STATUS:
 14 404
 7 200

ERRORS:
2026/02/13 11:11:38 [notice] 2203#2203: using inherited sockets from "5;6;"

? q
Saved 1 message in /home/vagrant/mbox
Held 0 messages in /var/mail/vagrant
```
