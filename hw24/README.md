## Цель домашнего задания:

Настраиваем split-dns

## Описание домашнего задания:

Создать домашнюю сетевую лабораторию;
Изучить основы DNS;
Научиться работать с технологией Split-DNS в Linux-based системах.


## Vagrantfile

```bash
Vagrant.configure(2) do |config|
  config.vm.box = "bento/centos-stream-9"

  config.vm.provision "ansible" do |ansible|
    #ansible.verbose = "vvv"
    ansible.playbook = "provisioning/playbook.yml"
    ansible.become = "true"
  end


  config.vm.provider "virtualbox" do |v|
	  v.memory = 768
  end

  config.vm.define "ns01" do |ns01|
    ns01.vm.network "private_network", ip: "192.168.50.10", virtualbox__intnet: "dns"
    ns01.vm.hostname = "ns01"
  end

  config.vm.define "ns02" do |ns02|
    ns02.vm.network "private_network", ip: "192.168.50.11", virtualbox__intnet: "dns"
    ns02.vm.hostname = "ns02"
  end

  config.vm.define "client" do |client|
    client.vm.network "private_network", ip: "192.168.50.15", virtualbox__intnet: "dns"
    client.vm.hostname = "client"
  end

  config.vm.define "client2" do |client2|
    client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
    client2.vm.hostname = "client2"

  end

end
```

## playbook.yml

```bash
---
- hosts: all
  become: true
  tasks:

#Установка пакетов bind, bind-utils и ntp
  - name: install packages
    yum: name={{ item }} state=latest 
    with_items:
      - bind
      - bind-utils

  - name: start chronyd
    service: 
      name: chronyd
      state: restarted
      enabled: true

  - name: ensure firewalld is stopped
    service: name=firewalld state=stopped enabled=no

#Копирование файла named.zonetransfer.key на хосты с правами 0644
#Владелец файла — root, група файла — named
  - name: copy transferkey to all servers and the client
    copy: src=named.zonetransfer.key dest=/etc/named.zonetransfer.key owner=root group=named mode=0644

#Настройка хоста ns01
- hosts: ns01
  become: true
  tasks:
#Копирование конфигурации DNS-сервера
  - name: copy named.conf
    copy: src=master-named.conf dest=/etc/named.conf owner=root group=named mode=0640

#Копирование файлов с настроками зоны. 
#Будут скопированы все файлы, в имя которых начинается на «named.d»
  - name: copy zones
    copy: src={{ item }} dest=/etc/named/ owner=root group=named mode=0660
    with_fileglob:
      - named.d*
      - named.newdns.lab

#Копирование файла resolv.conf
  - name: copy resolv.conf to the servers
    template: 
      src: servers-resolv.conf.j2 
      dest: /etc/resolv.conf 
      owner: root 
      group: root
      mode: 0644

#Изменение прав каталога /etc/named
#Права 670, владелец — root, группа — named  
  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

#Перезапуск службы Named и добавление её в автозагрузку
  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes

- hosts: ns02
  become: true
  tasks:
  - name: copy named.conf
    copy: src=slave-named.conf dest=/etc/named.conf owner=root group=named mode=0640

  - name: copy resolv.conf to the servers
    template: 
      src: servers-resolv.conf.j2 
      dest: /etc/resolv.conf 
      owner: root 
      group: root
      mode: 0644

  - name: set /etc/named permissions
    file: path=/etc/named owner=root group=named mode=0670

  - name: ensure named is running and enabled
    service: name=named state=restarted enabled=yes
    
- hosts: client,client2
  become: true
  tasks:
  - name: copy resolv.conf to the client
    copy: src=client-resolv.conf dest=/etc/resolv.conf owner=root group=root mode=0644

#Копирование конфигруационного файла rndc
  - name: copy rndc conf file
    copy: src=rndc.conf dest=/home/vagrant/rndc.conf owner=vagrant group=vagrant mode=0644
#Настройка сообщения при входе на сервер
  - name: copy motd to the client
    copy: src=client-motd dest=/etc/motd owner=root group=root mode=0644
```

## Работа со стендом и настройка DNS

```bash
[vagrant@client ~]$ dig @192.168.50.10 web1.dns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.10 web1.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48867
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 05975ad1aead880f010000006a12e2c134276f5c6544c5f5 (good)
;; QUESTION SECTION:
;web1.dns.lab.			IN	A

;; ANSWER SECTION:
web1.dns.lab.		3600	IN	A	192.168.50.15

;; Query time: 2 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun May 24 11:36:33 UTC 2026
;; MSG SIZE  rcvd: 85



[vagrant@client2 ~]$ dig @192.168.50.11 web2.dns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.11 web2.dns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 63252
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 9dac7f2a65b09ab9010000006a12e2ea920e06c812c0f171 (good)
;; QUESTION SECTION:
;web2.dns.lab.			IN	A

;; ANSWER SECTION:
web2.dns.lab.		3600	IN	A	192.168.50.16

;; Query time: 2 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Sun May 24 11:37:14 UTC 2026
;; MSG SIZE  rcvd: 85



[vagrant@client2 ~]$ dig @192.168.50.11 www.newdns.lab

; <<>> DiG 9.16.23-RH <<>> @192.168.50.11 www.newdns.lab
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 15169
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1232
; COOKIE: 59d10af71aea9845010000006a12e321a9ded2f8b4ba15eb (good)
;; QUESTION SECTION:
;www.newdns.lab.			IN	A

;; ANSWER SECTION:
www.newdns.lab.		3600	IN	A	192.168.50.16
www.newdns.lab.		3600	IN	A	192.168.50.15

;; Query time: 3 msec
;; SERVER: 192.168.50.11#53(192.168.50.11)
;; WHEN: Sun May 24 11:38:09 UTC 2026
;; MSG SIZE  rcvd: 103
```

## Настройка Split-DNS

### client видит обе зоны (dns.lab и newdns.lab), однако информацию о хосте web2.dns.lab он получить не может

```bash
[vagrant@client ~]$ ping www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.025 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.038 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.084 ms
^C
--- www.newdns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2005ms
rtt min/avg/max/mdev = 0.025/0.049/0.084/0.025 ms

[vagrant@client ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client (192.168.50.15): icmp_seq=1 ttl=64 time=0.026 ms
64 bytes from client (192.168.50.15): icmp_seq=2 ttl=64 time=0.072 ms
64 bytes from client (192.168.50.15): icmp_seq=3 ttl=64 time=0.037 ms
64 bytes from client (192.168.50.15): icmp_seq=4 ttl=64 time=0.113 ms
^C
--- web1.dns.lab ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
rtt min/avg/max/mdev = 0.026/0.062/0.113/0.034 ms

[vagrant@client ~]$ ping web2.dns.lab
ping: web2.dns.lab: Name or service not known
```

### client2 видит всю зону dns.lab и не видит зону newdns.lab

```bash
[vagrant@client2 ~]$ ping www.newdns.lab
ping: www.newdns.lab: Name or service not known

[vagrant@client2 ~]$ ping web1.dns.lab
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=1.88 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=1.11 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=3 ttl=64 time=0.766 ms
^C
--- web1.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 0.766/1.250/1.876/0.464 ms

[vagrant@client2 ~]$ ping web2.dns.lab
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.023 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.044 ms
64 bytes from client2 (192.168.50.16): icmp_seq=3 ttl=64 time=0.047 ms
^C
--- web2.dns.lab ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 0.023/0.038/0.047/0.010 ms
```

### selinux не отключал, он не мешает

```bash
[vagrant@ns01 ~]$ sudo sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Memory protection checking:     actual (secure)
Max kernel policy version:      33

[vagrant@ns01 ~]$ sudo getenforce
Enforcing

```