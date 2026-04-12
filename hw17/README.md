>## Цель домашнего задания:

- научиться проектировать централизованный сбор логов;
- рассмотреть особенности разных платформ для сбора логов.

>## Описание домашнего задания:

- Поднимаем две машины — web и log.
- На web поднимаем nginx.
- Настраиваем центральный лог-сервер на любой системе по выбору:
    journald;
    rsyslog;
    elk.
- Настраиваем аудит, который будет отслеживать изменения конфигураций nginx.
- Все критичные логи с web должны собираться и локально и удаленно.
- Все логи с nginx должны уходить на удаленный сервер (локально только критичные).
- Логи аудита должны также уходить на удаленную систему.

### Vagrantfile

```bash
Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "web#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "web#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.network "forwarded_port", guest: 80, host: "8080"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "2"
        libvirt.memory = "2048"
      end
    end
    config.vm.define "log#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "log#{i}"
      node.vm.network "private_network", ip: "192.168.122.20#{i}"
      node.vm.network "forwarded_port", guest: 80, host: "8080"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "2"
        libvirt.memory = "2048"
      end
      if i == N
        config.vm.provision "ansible" do |ansible|
          ansible.playbook = "provision.yml"
        end    
      end
    end
  end
end
```
## ansible provision

```bash
---
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: yes
  when: ansible_hostname == 'web1'

- name: Install rsyslog
  ansible.builtin.apt:
    name: rsyslog
    state: present
    update_cache: yes

- name: Copy /etc/rsyslog.conf
  ansible.builtin.copy:
    src: ../files/rsyslog_server.conf
    dest: /etc/rsyslog.conf
    owner: root
    group: root
    mode: '0644'
  when: ansible_hostname == 'log1'

- name: Copy /etc/rsyslog.conf
  ansible.builtin.copy:
    src: ../files/rsyslog_client.conf
    dest: /etc/rsyslog.conf
    owner: root
    group: root
    mode: '0644'
  when: ansible_hostname == 'web1'

- name: Restart rsyslog
  ansible.builtin.service:
    name: rsyslog.service
    state: restarted

- name: Copy  /etc/nginx/nginx.conf
  ansible.builtin.copy:
    src: ../files/nginx.conf
    dest:  /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: '0644'
  when: ansible_hostname == 'web1'

- name: Restart nginx
  ansible.builtin.service:
    name: nginx.service
    state: restarted
  when: ansible_hostname == 'web1'
```

## логи на лог-сервере
```bash
vagrant@log1:/var/log/rsyslog/web1$ ll
total 44
drwxr-xr-x 2 syslog syslog 4096 Apr 12 16:31 ./
drwxr-xr-x 4 syslog syslog 4096 Apr 12 16:29 ../
-rw-r----- 1 syslog adm    1512 Apr 12 16:31 nginx_access.log
-rw-r----- 1 syslog adm     971 Apr 12 16:29 python3.log
-rw-r----- 1 syslog adm     586 Apr 12 16:29 rsyslogd.log
-rw-r----- 1 syslog adm     415 Apr 12 16:29 sshd.log
-rw-r----- 1 syslog adm    1571 Apr 12 16:29 sudo.log
-rw-r----- 1 syslog adm    1798 Apr 12 16:30 systemd.log
-rw-r----- 1 syslog adm     352 Apr 12 16:29 systemd-logind.log
-rw-r----- 1 syslog adm      94 Apr 12 16:29 systemd-resolved.log
-rw-r----- 1 syslog adm     238 Apr 12 16:29 systemd-timesyncd.log
vagrant@log1:/var/log/rsyslog/web1$ tail -f nginx_access.log
2026-04-12T16:31:21+00:00 web1 nginx_access: 192.168.122.1 - - [12/Apr/2026:16:31:21 +0000] "GET / HTTP/1.1" 200 409 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"
2026-04-12T16:31:22+00:00 web1 nginx_access: 192.168.122.1 - - [12/Apr/2026:16:31:22 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"
2026-04-12T16:31:22+00:00 web1 nginx_access: message repeated 2 times: [ 192.168.122.1 - - [12/Apr/2026:16:31:22 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"]
2026-04-12T16:31:23+00:00 web1 nginx_access: 192.168.122.1 - - [12/Apr/2026:16:31:23 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"
2026-04-12T16:31:23+00:00 web1 nginx_access: message repeated 5 times: [ 192.168.122.1 - - [12/Apr/2026:16:31:23 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"]
2026-04-12T16:31:24+00:00 web1 nginx_access: 192.168.122.1 - - [12/Apr/2026:16:31:24 +0000] "GET / HTTP/1.1" 304 0 "-" "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 YaBrowser/26.3.0.0 Safari/537.36"```