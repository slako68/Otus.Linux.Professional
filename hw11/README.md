>## Цель домашнего задания:

Работать с SELinux: диагностировать проблемы и модифицировать политики SELinux для корректной работы приложений, если это требуется.


>## Описание домашнего задания:

1. Запустить nginx на нестандартном порту 3-мя разными способами:
переключатели setsebool;
добавление нестандартного порта в имеющийся тип;
формирование и установка модуля SELinux.

🗂 Формат сдачи

README с описанием каждого решения (скриншоты и демонстрация приветствуются).


2. Обеспечить работоспособность приложения при включенном selinux.

развернуть приложенный стенд https://github.com/mbfx/otus-linux-adm/tree/master/selinux_dns_problems;
выяснить причину неработоспособности механизма обновления зоны (см. README);
предложить решение (или решения) для данной проблемы;
выбрать одно из решений для реализации, предварительно обосновав выбор;
реализовать выбранное решение и продемонстрировать его работоспособность.

🗂 Формат сдачи
README с анализом причины неработоспособности, возможными способами решения и обоснованием выбора одного из них;
исправленный стенд или демонстрация работоспособной системы скриншотами и описанием


## 1. Запустить nginx на нестандартном порту 3-мя разными способами.

### Разрешим в SELinux работу nginx на порту TCP 4881 c помощью переключателей setsebool.

```console
[root@selinux ~]# cat /var/log/audit/audit.log |grep denied
type=AVC msg=audit(1772260543.180:779): avc:  denied  { name_bind } for  pid=5411 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0


[root@selinux ~]# grep 1772260543.180:779 /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1772260543.180:779): avc:  denied  { name_bind } for  pid=5411 comm="nginx" src=4881 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0

	Was caused by:
	The boolean nis_enabled was set incorrectly. 
	Description:
	Allow nis to enabled

	Allow access by executing:
	# setsebool -P nis_enabled 1


[root@selinux ~]# setsebool -P nis_enabled on
[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2026-02-28 06:46:30 UTC; 35s ago
    Process: 5501 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 5502 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 5503 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 5505 (nginx)
      Tasks: 3 (limit: 12101)
     Memory: 2.9M
        CPU: 34ms
     CGroup: /system.slice/nginx.service
             ├─5505 "nginx: master process /usr/sbin/nginx"
             ├─5506 "nginx: worker process"
             └─5507 "nginx: worker process"

Feb 28 06:46:30 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Feb 28 06:46:30 selinux nginx[5502]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Feb 28 06:46:30 selinux nginx[5502]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Feb 28 06:46:30 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.


[root@selinux ~]# curl -s -o /dev/null -w "%{http_code}" http://localhost:4881
200


[root@selinux ~]# getsebool -a | grep nis_enabled
nis_enabled --> on
```

### Разрешим в SELinux работу nginx на порту TCP 4881 c помощью добавления нестандартного порта в имеющийся тип.

```console
[root@selinux ~]# setsebool -P nis_enabled off
[root@selinux ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.


[root@selinux ~]# semanage port -l | grep http
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989


[root@selinux ~]# semanage port -a -t http_port_t -p tcp 4881
[root@selinux ~]# semanage port -l | grep  http_port_t
http_port_t                    tcp      4881, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988


[root@selinux ~]# systemctl restart nginx
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2026-02-28 06:59:46 UTC; 7s ago
    Process: 5537 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 5539 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 5540 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 5541 (nginx)
      Tasks: 3 (limit: 12101)
     Memory: 2.9M
        CPU: 36ms
     CGroup: /system.slice/nginx.service
             ├─5541 "nginx: master process /usr/sbin/nginx"
             ├─5542 "nginx: worker process"
             └─5543 "nginx: worker process"

Feb 28 06:59:46 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Feb 28 06:59:46 selinux nginx[5539]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Feb 28 06:59:46 selinux nginx[5539]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Feb 28 06:59:46 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.

[root@selinux ~]#  curl -s -o /dev/null -w "%{http_code}" http://localhost:4881
200
```

### Разрешим в SELinux работу nginx на порту TCP 4881 c помощью формирования и установки модуля SELinux.

```console
[root@selinux ~]# systemctl restart nginx
Job for nginx.service failed because the control process exited with error code.
See "systemctl status nginx.service" and "journalctl -xeu nginx.service" for details.

type=SYSCALL msg=audit(1772262164.101:842): arch=c000003e syscall=49 success=no exit=-13 a0=6 a1=55b2b0ecf6b0 a2=10 a3=7ffd6dbe4d70 items=0 ppid=1 pid=5586 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1772262164.102:843): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"

[root@selinux ~]# grep nginx /var/log/audit/audit.log | audit2allow -M nginx
******************** IMPORTANT ***********************
To make this policy package active, execute:

semodule -i nginx.pp

[root@selinux ~]# semodule -i nginx.pp
[root@selinux ~]# systemctl start nginx
[root@selinux ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Sat 2026-02-28 07:12:03 UTC; 14s ago
    Process: 5614 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 5615 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 5616 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 5617 (nginx)
      Tasks: 3 (limit: 12101)
     Memory: 2.9M
        CPU: 34ms
     CGroup: /system.slice/nginx.service
             ├─5617 "nginx: master process /usr/sbin/nginx"
             ├─5618 "nginx: worker process"
             └─5619 "nginx: worker process"

Feb 28 07:12:03 selinux systemd[1]: Starting The nginx HTTP and reverse proxy server...
Feb 28 07:12:03 selinux nginx[5615]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Feb 28 07:12:03 selinux nginx[5615]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Feb 28 07:12:03 selinux systemd[1]: Started The nginx HTTP and reverse proxy server.
```

## 2. Обеспечение работоспособности приложения при включенном SELinux.


### Попробуем внести изменения в зону на клиенте

```console
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
update failed: SERVFAIL

[vagrant@client ~]$ 
[vagrant@client ~]$ 
[vagrant@client ~]$ sudo -i
[root@client ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1772263431.655:773): avc:  denied  { dac_read_search } for  pid=3647 comm="20-chrony-dhcp" capability=2  scontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tcontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tclass=capability permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.

type=AVC msg=audit(1772263431.655:773): avc:  denied  { dac_override } for  pid=3647 comm="20-chrony-dhcp" capability=1  scontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tcontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tclass=capability permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.
```

### Смотрим ошибки на сервере

``` console
slako68@slako68-hp:~/otus/Otus.Linux.Professional/hw11/part2$ vagrant ssh ns01
Last login: Sat Feb 28 07:25:00 2026 from 192.168.121.1
[vagrant@ns01 ~]$ sudo -i
[root@ns01 ~]# cat /var/log/audit/audit.log | audit2why
type=AVC msg=audit(1772263434.778:773): avc:  denied  { dac_read_search } for  pid=3647 comm="20-chrony-dhcp" capability=2  scontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tcontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tclass=capability permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.

type=AVC msg=audit(1772263434.778:773): avc:  denied  { dac_override } for  pid=3647 comm="20-chrony-dhcp" capability=1  scontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tcontext=system_u:system_r:NetworkManager_dispatcher_chronyc_t:s0 tclass=capability permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.

type=AVC msg=audit(1772267369.521:1776): avc:  denied  { write } for  pid=8707 comm="isc-net-0000" name="dynamic" dev="vda4" ino=16975545 scontext=system_u:system_r:named_t:s0 tcontext=unconfined_u:object_r:named_conf_t:s0 tclass=dir permissive=0

	Was caused by:
		Missing type enforcement (TE) allow rule.

		You can use audit2allow to generate a loadable module to allow this access.


[root@ns01 ~]# ls -alZ /var/named/named.localhost
-rw-r-----. 1 root named system_u:object_r:named_zone_t:s0 152 Nov 13 08:16 /var/named/named.localhost
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_conf_t:s0      121 Feb 28 07:24 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Feb 28 07:25 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_conf_t:s0   56 Feb 28 07:24 dynamic
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      784 Feb 28 07:24 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      610 Feb 28 07:24 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      609 Feb 28 07:24 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_conf_t:s0      657 Feb 28 07:24 named.newdns.lab


[root@ns01 ~]# sudo semanage fcontext -l | grep named
/dev/gpmdata                                       named pipe         system_u:object_r:gpmctl_t:s0 
/dev/initctl                                       named pipe         system_u:object_r:initctl_t:s0 
/dev/xconsole                                      named pipe         system_u:object_r:xconsole_device_t:s0 
/dev/xen/tapctrl.*                                 named pipe         system_u:object_r:xenctl_t:s0 
/etc/named(/.*)?                                   all files          system_u:object_r:named_conf_t:s0 
/etc/named\.caching-nameserver\.conf               regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.conf                                   regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.rfc1912.zones                          regular file       system_u:object_r:named_conf_t:s0 
/etc/named\.root\.hints                            regular file       system_u:object_r:named_conf_t:s0 
/etc/rc\.d/init\.d/named                           regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rc\.d/init\.d/named-sdb                       regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rc\.d/init\.d/unbound                         regular file       system_u:object_r:named_initrc_exec_t:s0 
/etc/rndc.*                                        regular file       system_u:object_r:named_conf_t:s0 
/etc/unbound(/.*)?                                 all files          system_u:object_r:named_conf_t:s0 
/usr/lib/systemd/system/named-sdb.*                regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/system/named.*                    regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/system/unbound.*                  regular file       system_u:object_r:named_unit_file_t:s0 
/usr/lib/systemd/systemd-hostnamed                 regular file       system_u:object_r:systemd_hostnamed_exec_t:s0 
/usr/sbin/lwresd                                   regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named                                    regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named-checkconf                          regular file       system_u:object_r:named_checkconf_exec_t:s0 
/usr/sbin/named-pkcs11                             regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/named-sdb                                regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound                                  regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-anchor                           regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-checkconf                        regular file       system_u:object_r:named_exec_t:s0 
/usr/sbin/unbound-control                          regular file       system_u:object_r:named_exec_t:s0 
/usr/share/munin/plugins/named                     regular file       system_u:object_r:services_munin_plugin_exec_t:s0 
/var/lib/softhsm(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
/var/lib/unbound(/.*)?                             all files          system_u:object_r:named_cache_t:s0 
/var/log/named.*                                   regular file       system_u:object_r:named_log_t:s0 
/var/named(/.*)?                                   all files          system_u:object_r:named_zone_t:s0 
```

### Изменим тип контекста безопасности для каталога /etc/named

```console
[root@ns01 ~]# sudo chcon -R -t named_zone_t /etc/named
[root@ns01 ~]# ls -laZ /etc/named
total 28
drw-rwx---.  3 root named system_u:object_r:named_zone_t:s0      121 Feb 28 07:24 .
drwxr-xr-x. 85 root root  system_u:object_r:etc_t:s0            8192 Feb 28 07:25 ..
drw-rwx---.  2 root named unconfined_u:object_r:named_zone_t:s0   56 Feb 28 07:24 dynamic
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      784 Feb 28 07:24 named.50.168.192.rev
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      610 Feb 28 07:24 named.dns.lab
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      609 Feb 28 07:24 named.dns.lab.view1
-rw-rw----.  1 root named system_u:object_r:named_zone_t:s0      657 Feb 28 07:24 named.newdns.lab
```

### Попробуем снова внести изменения с клиента

```console
[root@client ~]# nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit


[root@client ~]# dig www.ddns.lab

; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48107
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: b84ce8f477fc902b0100000069a2be4c6f713cf82f761686 (good)
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sat Feb 28 10:07:08 UTC 2026
;; MSG SIZE  rcvd: 85
```

### Изменения в playbook.yml

```
  - name: Изменим тип контекста безопасности для каталога /etc/named
    shell: |
        chcon -R -t named_zone_t /etc/named
```

### Проверяем после пересоздания ВМ

```console
Last login: Sat Feb 28 10:24:32 2026 from 192.168.121.1
[vagrant@client ~]$ nsupdate -k /etc/named.zonetransfer.key
> server 192.168.50.10
> zone ddns.lab
> update add www.ddns.lab. 60 A 192.168.50.15
> send
> quit
[vagrant@client ~]$ dig www.ddns.lab



; <<>> DiG 9.16.23-RH <<>> www.ddns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52373
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 1608dec43eaa04f20100000069a2c3264f822087e9a39cb2 (good)
;; QUESTION SECTION:
;www.ddns.lab.			IN	A

;; ANSWER SECTION:
www.ddns.lab.		60	IN	A	192.168.50.15

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sat Feb 28 10:27:50 UTC 2026
;; MSG SIZE  rcvd: 85
```


