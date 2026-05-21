## Цель домашнего задания:

Создать домашнюю сетевую лабораторию. Научиться настраивать VPN-сервер в Linux-based системах.

## Описание домашнего задания:

1. Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях

2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ


## TAP/TUN режимы VPN (part1)

### TAP режим

```bash
vagrant@client:~$ iperf3 -c 10.10.10.1 -t 40 -i 5 
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 52772 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  80.0 MBytes   134 Mbits/sec   17    387 KBytes       
[  5]   5.00-10.00  sec  80.5 MBytes   135 Mbits/sec  130    235 KBytes       
[  5]  10.00-15.00  sec  80.8 MBytes   136 Mbits/sec    3    321 KBytes       
[  5]  15.00-20.00  sec  81.1 MBytes   136 Mbits/sec    0    462 KBytes       
[  5]  20.00-25.00  sec  79.9 MBytes   134 Mbits/sec  140    346 KBytes       
[  5]  25.00-30.00  sec  80.3 MBytes   135 Mbits/sec  131    325 KBytes       
[  5]  30.00-35.00  sec  80.2 MBytes   135 Mbits/sec   58    307 KBytes       
[  5]  35.00-40.00  sec  79.8 MBytes   134 Mbits/sec    0    455 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   643 MBytes   135 Mbits/sec  479             sender
[  5]   0.00-40.07  sec   642 MBytes   134 Mbits/sec                  receiver

iperf Done.
```

### TUN режим

```bash
vagrant@client:~$ iperf3 -c 10.10.10.1 -t 40 -i 5 
Connecting to host 10.10.10.1, port 5201
[  5] local 10.10.10.2 port 40806 connected to 10.10.10.1 port 5201
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-5.00   sec  79.5 MBytes   133 Mbits/sec   86    333 KBytes       
[  5]   5.00-10.00  sec  79.1 MBytes   133 Mbits/sec    0    471 KBytes       
[  5]  10.00-15.00  sec  79.4 MBytes   133 Mbits/sec    0    578 KBytes       
[  5]  15.00-20.00  sec  79.1 MBytes   133 Mbits/sec    0   1015 KBytes       
[  5]  20.00-25.00  sec  79.8 MBytes   134 Mbits/sec  133    596 KBytes       
[  5]  25.00-30.00  sec  77.5 MBytes   130 Mbits/sec  466    147 KBytes       
[  5]  30.00-35.00  sec  78.8 MBytes   132 Mbits/sec    0    364 KBytes       
[  5]  35.00-40.00  sec  76.2 MBytes   128 Mbits/sec   89    197 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-40.00  sec   629 MBytes   132 Mbits/sec  774             sender
[  5]   0.00-40.06  sec   627 MBytes   131 Mbits/sec                  receiver

iperf Done.
```

### Замеры скорости в туннеле совсем не позволяют сделать следующие выводы:

```console
TAP:

Преимущества:

    ведёт себя как настоящий сетевой адаптер;

    поддерживает любые сетевые протоколы;

    позволяет создавать сетевые мосты;

    подходит для сценариев, где нужен L2‑доступ (например, для виртуальных машин или устройств в одном сегменте).

Недостатки:

    высокий объём трафика из‑за широковещательных пакетов;

    накладные расходы на Ethernet‑заголовки;

    плохая масштабируемость для больших сетей.

TUN:

Преимущества:

    низкий объём накладного трафика;

    передаёт только трафик, предназначенный для VPN‑клиента;

    хорошая масштабируемость;

    проще в настройке для стандартных VPN‑задач.

Недостатки:

    не передаёт широковещательный трафик (может быть проблемой для некоторых служб);

    поддерживает только IP‑протоколы;

    нельзя использовать в мостах.
```

## RAS на базе OpenVPN (part2)

```bash
- name: VPN
  hosts: all
  become: yes
  vars_files:
    - defaults/main.yml
  tasks:
    - name: set up forward packages across routers
      sysctl:
        name: net.ipv4.conf.all.forwarding
        value: '1'
        state: present

    - name: install tools
      apt:
        name:
          - openvpn
          - easy-rsa
        state: present
        update_cache: true

    - name: Initialize PKI
      command: /usr/share/easy-rsa/easyrsa init-pki
      args:
        chdir: /etc/openvpn

    - name: Generate CA certificate
      shell: echo 'yes' | /usr/share/easy-rsa/easyrsa build-ca nopass
      args:
        chdir: /etc/openvpn

    - name: Generate server certificate and key
      shell: echo 'rasvpn' | /usr/share/easy-rsa/easyrsa gen-req server nopass
      args:
        chdir: /etc/openvpn

    - name: Sign server certificate
      shell: echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req server server
      args:
        chdir: /etc/openvpn

    - name: Generate Diffie-Hellman parameters
      command: /usr/share/easy-rsa/easyrsa gen-dh
      args:
        chdir: /etc/openvpn

    - name: Generate CA certificate
      command: openvpn --genkey secret ca.key
      args:
        chdir: /etc/openvpn

    - name: Generate client certificate and key
      shell: echo 'client' | /usr/share/easy-rsa/easyrsa gen-req client nopass
      args:
        chdir: /etc/openvpn

    - name: Sign client certificate
      shell: echo 'yes' | /usr/share/easy-rsa/easyrsa sign-req client client
      args:
        chdir: /etc/openvpn

    - name: server.conf 
      template:
        src: server.conf
        dest: /etc/openvpn/server.conf
        mode: 0644

    - name: iroute
      shell: "echo 'iroute 10.10.10.0 255.255.255.0' > /etc/openvpn/client/client"

    - name: openvpn@.service 
      template:
        src: openvpn@.service
        dest: /etc/systemd/system/openvpn@.service
        mode: 0644

    - name: Restart services
      ansible.builtin.systemd:
        name: openvpn@server
        state: started
        enabled: yes
        daemon_reload: true

    - name: restart all hosts
      reboot:
        reboot_timeout: 600

    - name: client.conf 
      become: false
      template:
        src: client.conf
        dest: ./
      delegate_to: localhost

    - name: Fetch file from server
      fetch:
        src: /etc/openvpn/pki/private/client.key
        dest: ./
        flat: yes
      delegate_to: server

    - name: Fetch file from server
      fetch:
        src: /etc/openvpn/pki/ca.crt 
        dest: ./
        flat: yes
      delegate_to: server

    - name: Fetch file from server
      fetch:
        src: /etc/openvpn/pki/issued/client.crt 
        dest: ./
        flat: yes
      delegate_to: server

    - name: mode 0600
      file:
        path: ./client.key
        state: file
        mode: '0600'
      delegate_to: localhost
```


```bash
vagrant@client:/vagrant/ansible$ ip r
default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100 
10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100 
10.0.2.2 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.0.2.3 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100 
10.10.10.0/24 via 10.10.10.5 dev tun0 
10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 


vagrant@client:/vagrant/ansible$ ping 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=3.19 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=3.18 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=3.29 ms
64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=3.00 ms
64 bytes from 10.10.10.1: icmp_seq=5 ttl=64 time=2.98 ms
64 bytes from 10.10.10.1: icmp_seq=6 ttl=64 time=2.90 ms
64 bytes from 10.10.10.1: icmp_seq=7 ttl=64 time=2.63 ms
64 bytes from 10.10.10.1: icmp_seq=8 ttl=64 time=2.73 ms
^C
--- 10.10.10.1 ping statistics ---
8 packets transmitted, 8 received, 0% packet loss, time 7011ms
rtt min/avg/max/mdev = 2.629/2.987/3.289/0.216 ms
```
