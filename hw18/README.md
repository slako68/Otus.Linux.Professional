>## Цель домашнего задания:

Настроить бэкапы.

>## Описание домашнего задания:

Настроить удаленный бекап каталога /etc c сервера client при помощи borgbackup. Резервные копии должны соответствовать следующим критериям:

- директория для резервных копий /var/backup. Это должна быть отдельная точка монтирования. В данном случае для демонстрации размер не принципиален, достаточно будет и 2GB;
- репозиторий дле резервных копий должен быть зашифрован ключом или паролем - на ваше усмотрение;
имя бекапа должно содержать информацию о времени снятия бекапа;
- глубина бекапа должна быть год, хранить можно по последней копии на конец месяца, кроме последних трех.
Последние три месяца должны содержать копии на каждый день. Т.е. должна быть правильно настроена политика удаления старых бэкапов;
- резервная копия снимается каждые 5 минут. Такой частый запуск в целях демонстрации;
- написан скрипт для снятия резервных копий. Скрипт запускается из соответствующей Cron джобы, либо systemd timer-а - на ваше усмотрение;
- настроено логирование процесса бекапа. Для упрощения можно весь вывод перенаправлять в logger с соответствующим тегом. Если настроите не в syslog, то обязательна ротация логов.

### ANSIBLE_ARGS="-e pass=Otus1234" vagrant up

```bash
Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "client#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "client#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.network "forwarded_port", guest: 80, host: "8080"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "2"
        libvirt.memory = "2048"
      end
    end
    config.vm.define "server#{i}" do |node|
      node.vm.box = "bento/ubuntu-24.04"
      node.vm.hostname = "server#{i}"
      node.vm.network "private_network", ip: "192.168.122.20#{i}"
      node.vm.network "forwarded_port", guest: 80, host: "8080"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "2"
        libvirt.memory = "2048"
        M = 1
        (1..M).each do |j|
          libvirt.storage :file, :size => '2G'
        end
      end
      if i == N
        config.vm.provision "ansible" do |ansible|
          ansible.playbook = "provision.yml"
          ansible.raw_arguments = Shellwords.shellsplit(ENV['ANSIBLE_ARGS']) if ENV['ANSIBLE_ARGS']
        end    
      end
    end
  end
end
```
## ansible provision

```bash
---
- name: Install borgbackup
  ansible.builtin.apt:
    name: borgbackup
    state: present
    update_cache: yes

- name: Format the volume with ext4 fs
  community.general.filesystem:
    fstype: ext4
    dev: /dev/vdb
  when: ansible_hostname == 'server1'

- name: Create /var/backup
  ansible.builtin.file:
    path: /var/backup
    state: directory
    owner: vagrant
    group: vagrant
    mode: '0755'
  when: ansible_hostname == 'server1'

- name: Mount ext4
  mount:
    path: /var/backup
    src: /dev/vdb
    fstype: ext4
    state: mounted
  when: ansible_hostname == 'server1'

- name: Recursively change ownership of a directory
  ansible.builtin.file:
    path: /var/backup
    state: directory
    recurse: yes
    owner: vagrant
    group: vagrant
  when: ansible_hostname == 'server1'

- name: Recursively remove directory lost+found
  ansible.builtin.file:
    path: /var/backup/lost+found/
    state: absent

- name: Create /root/.ssh
  become: true
  ansible.builtin.file:
    path: /root/.ssh
    state: directory
    owner: root
    group: root
    mode: '0700'
  when: ansible_hostname == 'client1'

- name: Copy .vagrant/machines/server1/libvirt/private_key
  become: true
  ansible.builtin.copy:
    src: .vagrant/machines/server1/libvirt/private_key
    dest: /root/.ssh/id_rsa
    owner: root
    group: root
    mode: '0600'
  when: ansible_hostname == 'client1'

- name: Copy config
  become: true
  ansible.builtin.copy:
    src: config
    dest: /root/.ssh/config
    owner: root
    group: root
    mode: '0600'
  when: ansible_hostname == 'client1'

- name: Create /etc/borg
  ansible.builtin.file:
    path: /etc/borg
    state: directory
  when: ansible_hostname == 'client1'

- name: Create /etc/borg/borg.env
  ansible.builtin.shell: |
    cat > /etc/borg/borg.env <<'EOF'
    BORG_PASSPHRASE={{ pass }}
    EOF
  when: ansible_hostname == 'client1'

- name: Copy borg-backup.service
  ansible.builtin.copy:
    src: borg-backup.service
    dest: /etc/systemd/system/borg-backup.service
  when: ansible_hostname == 'client1'

- name: Copy borg-backup.timer
  ansible.builtin.copy:
    src: borg-backup.timer
    dest: /etc/systemd/system/borg-backup.timer
  when: ansible_hostname == 'client1'

- name: Make sure a service borg-backup.timer is running
  ansible.builtin.systemd_service:
    state: started
    name: borg-backup.timer
    enabled: true
    daemon_reload: true
  when: ansible_hostname == 'client1'

- name: Start borg-backup.service
  ansible.builtin.systemd_service:
    state: started
    name: borg-backup.service
  when: ansible_hostname == 'client1'
```
## Сервис
```bash
[Unit]
Description=Borg Backup

[Service]
Type=oneshot
User=vagrant

# Парольная фраза
EnvironmentFile=/etc/borg/borg.env
# Репозиторий
Environment=REPO=vagrant@192.168.122.201:/var/backup/
# Что бэкапим
Environment=BACKUP_TARGET=/etc

# Создание бэкапа
ExecStart=/bin/borg create \
    --stats                \
    ${REPO}::etc-{now:%%Y-%%m-%%d_%%H:%%M:%%S} ${BACKUP_TARGET}

# Проверка бэкапа
ExecStart=/bin/borg check ${REPO}

# Очистка старых бэкапов
ExecStart=/bin/borg prune \
    --keep-daily  90      \
    --keep-monthly 12     \
    --keep-yearly  1       \
    ${REPO}
```

## Таймер

```bash
[Unit]
Description=Borg Backup

[Timer]
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target

```

##  Borg init
```bash
vagrant@client1:~$ sudo borg init --encryption=repokey vagrant@192.168.122.201:/var/backup/
A repository already exists at vagrant@192.168.122.201:/var/backup/.
vagrant@client1:~$ ^C
vagrant@client1:~$ sudo borg init --encryption=repokey vagrant@192.168.122.201:/var/backup/
Enter new passphrase: 
Enter same passphrase again: 
Do you want your passphrase to be displayed for verification? [yN]: N

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://vagrant@192.168.122.201/var/backup

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
If you used a repokey mode, the key is stored in the repo, but you should back it up separately.
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s).
```

## Список бэкапов

```bash
vagrant@client1:~$ borg list vagrant@192.168.122.201:/var/backup/
Enter passphrase for key ssh://vagrant@192.168.122.201/var/backup: 
etc-2026-04-18_06:41:19              Sat, 2026-04-18 06:41:33 [fa967436030bdaea9825f4c4d6aafad6f4460220395e90655e4e77e9fe233fe8]
etc-2026-04-18_07:02:33              Sat, 2026-04-18 07:02:33 [bf3740546bcd919e9e256e5cbfd9a52012966be379484bf8703c8cdecc7cd8d3]
etc-2026-04-18_07:04:35              Sat, 2026-04-18 07:04:36 [a9a8791e75936560723e98092fb8618d855ec8f3a63ca86576a510812ce0b354]
etc-2026-04-18_07:09:53              Sat, 2026-04-18 07:09:54 [feb0dcf011d717d53f343efa6364de3bac58d9f9fa1b65c1d6d65c4d48b31b2c]
etc-2026-04-18_07:15:23              Sat, 2026-04-18 07:15:24 [d5bd0eea4b090f0489c11ce6c3865812899568a5031bff77c50ee7c727425b64]```

## Список файлов

```bash
vagrant@client1:~$ borg list vagrant@192.168.122.201:/var/backup/::etc-2026-04-18_07:15:23
Enter passphrase for key ssh://vagrant@192.168.122.201/var/backup: 
drwxr-xr-x root   root          0 Sat, 2026-04-18 06:37:53 etc
lrwxrwxrwx root   root         27 Sun, 2025-02-16 20:57:55 etc/localtime -> /usr/share/zoneinfo/Etc/UTC
lrwxrwxrwx root   root         19 Sun, 2025-02-16 20:57:44 etc/mtab -> ../proc/self/mounts
lrwxrwxrwx root   root         21 Wed, 2025-02-05 16:08:58 etc/os-release -> ../usr/lib/os-release
lrwxrwxrwx root   root         39 Sun, 2025-02-16 20:58:04 etc/resolv.conf -> ../run/systemd/resolve/stub-resolv.conf
lrwxrwxrwx root   root         13 Mon, 2024-04-08 16:20:47 etc/rmt -> /usr/sbin/rmt
lrwxrwxrwx root   root         16 Sun, 2025-02-16 20:57:44 etc/vconsole.conf -> default/keyboard
lrwxrwxrwx root   root         23 Mon, 2024-02-26 12:58:31 etc/vtrgb -> /etc/alternatives/vtrgb
drwxr-xr-x root   root          0 Sun, 2025-02-16 21:04:48 etc/ModemManager
drwxr-xr-x root   root          0 Sun, 2025-02-16 21:04:48 etc/ModemManager/connection.d
drwxr-xr-x root   root          0 Sun, 2025-02-16 21:04:48 etc/ModemManager/fcc-unlock.d
drwxr-xr-x root   root          0 Sun, 2025-02-16 20:58:19 etc/PackageKit
-rw-r--r-- root   root        706 Wed, 2023-11-08 20:35:41 etc/PackageKit/PackageKit.conf
-rw-r--r-- root   root       1718 Fri, 2024-12-13 17:07:28 etc/PackageKit/Vendor.conf
drwxr-xr-x root   root          0 Sun, 2025-02-16 20:57:47 etc/X11
drwxr-xr-x root   root          0 Sun, 2025-02-16 20:58:05 etc/X11/Xsession.d
-rw-r--r-- root 
```