## Цель домашнего задания:

- настроить потоковую репликацию PostgreSQL со слотами и реализовать корректное резервное копирование для обеспечения отказоустойчивости сервиса;

## Описание домашнего задания:

- настроить hot_standby репликацию с использованием слотов
- настроить правильное резервное копирование

## Vagrantfile
```bash
# Описание параметров ВМ
MACHINES = {
  # Имя DV "pam"
  :node1 => {
        # VM box
        :box_name => "bento/ubuntu-24.04",
        # Имя VM
        :vm_name => "node1",
        # Количество ядер CPU
        :cpus => 2,
        # Указываем количество ОЗУ (В Мегабайтах)
        :memory => 2048,
        # Указываем IP-адрес для ВМ
        :ip => "192.168.57.11",
  },
  :node2 => {
        :box_name => "bento/ubuntu-24.04",
        :vm_name => "node2",
        :cpus => 2,
        :memory => 2048,
        :ip => "192.168.57.12",

  },
  :barman => {
        :box_name => "bento/ubuntu-24.04",
        :vm_name => "barman",
        :cpus => 2,
        :memory => 2048,
        :ip => "192.168.57.13",

  },

}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|
    
    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      box.vm.network "private_network", ip: boxconfig[:ip]
      box.vm.provider "virtualbox" do |v|
        v.memory = boxconfig[:memory]
        v.cpus = boxconfig[:cpus]
      end

      # Запуск ansible-playbook
      if boxconfig[:vm_name] == "barman"
       box.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/provision.yml"
        ansible.inventory_path = "ansible/hosts"
        ansible.host_key_checking = "false"
        ansible.limit = "all"
       end
      end
    end
  end
end
```

## Настройка репликации

```bash
---
# Установка python-пакетов для модулей psql
  - name: install base tools
    apt:
      name:
        - python3-pexpect
        - python3-psycopg2
      state: present
      update_cache: true

#CREATE USER replicator WITH REPLICATION Encrypted PASSWORD 'Otus2022!';
  - name: Create replicator user
    become_user: postgres
    postgresql_user:
      name: replication
      password: '{{ replicator_password }}'
      role_attr_flags: REPLICATION 
    ignore_errors: true
    when: (ansible_hostname == "node1")

  #Останавливаем postgresql на хосте node2
  - name: stop postgresql-server on node2
    service: 
      name: postgresql
      state: stopped
    when: (ansible_hostname == "node2")

  #Копируем конфигурационный файл postgresql.conf
  - name: copy postgresql.conf
    template:
      src: postgresql.conf.j2
      dest: /etc/postgresql/{{ pg_ver }}/main/postgresql.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node1")
  
  #Копируем конфигурационный файл pg_hba.conf
  - name: copy pg_hba.conf
    template:
      src: pg_hba.conf.j2
      dest: /etc/postgresql/{{ pg_ver }}/main/pg_hba.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node1")
   #Перезапускаем службу  postgresql
  - name: restart postgresql-server on node1
    service: 
      name: postgresql
      state: restarted
    when: (ansible_hostname == "node1")

  #Удаляем содержимое каталога /var/lib/postgresql/18/main/
  - name: Remove files from data catalog
    file:
      path: /var/lib/postgresql/{{ pg_ver }}/main/
      state: absent
    when: (ansible_hostname == "node2")

  #Копируем данные с node1 на node2
  - name: copy files from master to slave
    become_user: postgres
    expect:
      command: 'pg_basebackup -h {{ master_ip }} -U  replication -p 5432 -D /var/lib/postgresql/{{ pg_ver }}/main/ -R -P'
      responses: 
        '.*Password*': "{{ replicator_password }}"
    when: (ansible_hostname == "node2")

  #Копируем конфигурационный файл postgresql.conf
  - name: copy postgresql.conf
    template:
      src: postgresql.conf.j2
      dest:  /etc/postgresql/{{ pg_ver }}/main/postgresql.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node2")

  #Копируем конфигурационный файл pg_hba.conf
  - name: copy pg_hba.conf
    template:
      src: pg_hba.conf.j2
      dest:  /etc/postgresql/{{ pg_ver }}/main/pg_hba.conf
      owner: postgres
      group: postgres
      mode: '0600'
    when: (ansible_hostname == "node2")
   
  #Запускаем службу postgresql на хосте node2
  - name: start postgresql-server on node2
    service: 
      name: postgresql
      state: started
    when: (ansible_hostname == "node2")
```

## Настройка резервного копирования

```bash
---
# Установка необходимых пакетов для работы с postgres и пользователями
  - name: install base tools
    apt:
      name:
        - python3-pexpect
        - python3-psycopg2
        - bash-completion 
        - wget 
      state: present
      update_cache: true

  #  Установка пакетов barman и postgresql-client на сервер barman 
  - name: install barman and postgresql packages on barman
    apt:
      name:
        - barman
        - barman-cli
        - postgresql-{{ pg_ver }}
      state: present
      update_cache: true
    when: (ansible_hostname == "barman")

 #  Установка пакетов barman-cli на серверах node1 и node2 
  - name: install barman-cli and postgresql packages on nodes
    apt:
      name:
        - barman-cli
      state: present
      update_cache: true
    when: (ansible_hostname != "barman")

#  Генерируем SSH-ключ для пользователя postgres на хосте node1
  - name: generate SSH key for postgres
    user:
      name: postgres
      generate_ssh_key: yes
      ssh_key_type: rsa
      ssh_key_bits: 4096
      force: no
    when: (ansible_hostname == "node1")
 
#  Генерируем SSH-ключ для пользователя barman на хосте barman
  - name: generate SSH key for barman
    user:
      name: barman
      uid: 994
      shell: /bin/bash
      generate_ssh_key: yes
      ssh_key_type: rsa
      ssh_key_bits: 4096
      force: no
    when: (ansible_hostname == "barman")

  #  Забираем содержимое открытого ключа postgres c хоста node1
  - name: fetch all public ssh keys node1
    shell: cat /var/lib/postgresql/.ssh/id_rsa.pub
    register: ssh_keys
    when: (ansible_hostname == "node1")

  #  Копируем ключ с barman на node1
  - name: transfer public key to barman
    delegate_to: barman
    authorized_key:
      key: "{{ ssh_keys.stdout }}"
      comment: "{{ansible_hostname}}"
      user: barman
    when: (ansible_hostname == "node1")

  #  Забираем содержимое открытого ключа barman c хоста barman 
  - name: fetch all public ssh keys barman
    shell: cat /var/lib/barman/.ssh/id_rsa.pub
    register: ssh_keys
    when: (ansible_hostname == "barman")

 #  Копируем ключ с node1 на barman
  - name: transfer public key to barman
    delegate_to: node1
    authorized_key:
      key: "{{ ssh_keys.stdout }}"
      comment: "{{ansible_hostname}}"
      user: postgres
    when: (ansible_hostname == "barman")

  #CREATE USER barman SUPERUSER;
  - name: Create barman user
    become_user: postgres
    postgresql_user:
      name: barman
      password: '{{ barman_user_password }}'
      role_attr_flags: SUPERUSER 
    ignore_errors: true
    when: (ansible_hostname == "node1")

   # Добавляем разрешения для подключения с хоста barman
  - name: Add permission for barman
    lineinfile:
      path: /etc/postgresql/{{ pg_ver }}/main/pg_hba.conf
      line: 'host    all   {{ barman_user }}    {{ barman_ip }}/32    scram-sha-256'
    when: (ansible_hostname == "node1") or
          (ansible_hostname == "node2") 

  # Добавляем разрешения для подключения с хоста barman
  - name: Add permission for barman
    lineinfile:
      path: /etc/postgresql/{{ pg_ver }}/main/pg_hba.conf
      line: 'host    replication   {{ barman_user }}    {{ barman_ip }}/32    scram-sha-256'
    when: (ansible_hostname == "node1") or
          (ansible_hostname == "node2") 

  # Перезагружаем службу postgresql-server
  - name: restart postgresql-server on node1
    service: 
      name: postgresql
      state: restarted
    when: (ansible_hostname == "node1")

  # Создаём БД otus;
  - name: Create DB for backup
    become_user: postgres
    postgresql_db:
      name: otus
      encoding: UTF-8
      template: template0
      state: present
    when: (ansible_hostname == "node1")

  # Создаем таблицу test1 в БД otus;
  - name: Add tables to otus_backup
    become_user: postgres
    postgresql_table:
      db: otus
      name: test1
      state: present
    when: (ansible_hostname == "node1")

  # Копируем файл .pgpass
  - name: copy .pgpass
    template:
      src: .pgpass.j2
      dest: /var/lib/barman/.pgpass
      owner: barman
      group: barman
      mode: '0600'
    when: (ansible_hostname == "barman")

  # Копируем файл barman.conf
  - name: copy barman.conf
    template:
      src: barman.conf.j2
      dest: /etc/barman.conf 
      owner: barman
      group: barman
      mode: '0755'
    when: (ansible_hostname == "barman")

 # Копируем файл node1.conf
  - name: copy node1.conf
    template:
      src: node1.conf.j2
      dest: /etc/barman.d/node1.conf
      owner: barman
      group: barman
      mode: '0755'
    when: (ansible_hostname == "barman")

  - name: barman switch-wal node1
    become_user: barman
    shell: barman switch-wal node1
    when: (ansible_hostname == "barman")

  - name: barman cron
    become_user: barman
    shell: barman cron
    when: (ansible_hostname == "barman")
```

## postgresql.conf

```bash
data_directory = '/var/lib/postgresql/16/main'		# use data in another directory
hba_file = '/etc/postgresql/16/main/pg_hba.conf'	# host-based authentication file
ident_file = '/etc/postgresql/16/main/pg_ident.conf'	# ident configuration file
external_pid_file = '/var/run/postgresql/16-main.pid'			# write an extra PID file
listen_addresses = 'localhost, {{ ansible_eth1.ipv4.address }}'
port = 5432				# (change requires restart)
max_connections = 100			# (change requires restart)
unix_socket_directories = '/var/run/postgresql' # comma-separated list of directories
#ssl = on
#ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
#ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'
shared_buffers = 128MB			# min 128kB
dynamic_shared_memory_type = posix	# the default is usually the first option
max_wal_size = 1GB
min_wal_size = 80MB
log_line_prefix = '%m [%p] %q%u@%d '		# special values:
log_timezone = 'UTC+3'
cluster_name = '16/main'			# added to process titles if nonempty
datestyle = 'iso, mdy'
timezone = 'UTC+3'
lc_messages = 'en_US.UTF-8'		# locale for system error message
lc_monetary = 'en_US.UTF-8'		# locale for monetary formatting
lc_numeric = 'en_US.UTF-8'		# locale for number formatting
lc_time = 'en_US.UTF-8'			# locale for time formatting
default_text_search_config = 'pg_catalog.english'
include_dir = 'conf.d'
#можно или нет подключаться к postgresql для выполнения запросов в процессе восстановления; 
hot_standby = on
#Включаем репликацию
wal_level = replica
#Количество планируемых слейвов
max_wal_senders = 3
#Максимальное количество слотов репликации
max_replication_slots = 3
#будет ли сервер slave сообщать мастеру о запросах, которые он выполняет.
hot_standby_feedback = on
#Включаем использование зашифрованных паролей
password_encryption = scram-sha-256
```

## pg_hba.cong
```bash
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all         all                                    peer
# IPv4 local connections:
host    all         all            127.0.0.1/32            scram-sha-256
# IPv6 local connections:
host    all         all            ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the replication privilege.
local   replication all                                    peer
host    replication all            127.0.0.1/32            scram-sha-256
host    replication all            ::1/128                 scram-sha-256
host    replication replication    {{ master_ip }}/32      scram-sha-256
host    replication replication    {{ slave_ip }}/32       scram-sha-256
```

## barman.conf

```bash
[barman]
#Указываем каталог, в котором будут храниться бекапы
barman_home = /var/lib/barman
#Указываем каталог, в котором будут храниться файлы конфигурации бекапов
configuration_files_directory = /etc/barman.d
#пользователь, от которого будет запускаться barman
barman_user = barman
#расположение файла с логами
log_file = /var/log/barman/barman.log
#Используемый тип сжатия
compression = gzip
#Используемый метод бекапа
backup_method = rsync
archiver = on
retention_policy = REDUNDANCY 3
immediate_checkpoint = true
#Глубина архива
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1
```

## node1.conf

```bash
[node1]
#Описание задания
description = "backup node1"
#Команда подключения к хосту node1
ssh_command = ssh postgres@192.168.57.11 
#Команда для подключения к postgres-серверу
conninfo = host=192.168.57.11 user=barman port=5432 dbname=postgres
retention_policy_mode = auto
retention_policy = RECOVERY WINDOW OF 7 days
wal_retention_policy = main
streaming_archiver=on
#Указание префикса, который будет использоваться как $PATH на хосте node1
path_prefix = /usr/pgsql-16/bin/
#настройки слота
create_slot = auto
slot_name = node1
#Команда для потоковой передачи от postgres-сервера
streaming_conninfo = host=192.168.57.11 user=barman 
#Тип выполняемого бекапа
backup_method = postgres
archiver = off
```

## Проверка репликации

```bash
vagrant@node1:~$ sudo -u postgres psql
psql (16.14 (Ubuntu 16.14-0ubuntu0.24.04.1))
Type "help" for help.

postgres=# CREATE DATABASE otus_test;
CREATE DATABASE
postgres=# \l
                                                       List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | ICU Locale | ICU Rules |   Access privileges   
-----------+----------+----------+-----------------+-------------+-------------+------------+-----------+-----------------------
 otus_test | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | 
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | 
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | =c/postgres          +
           |          |          |                 |             |             |            |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | =c/postgres          +
           |          |          |                 |             |             |            |           | postgres=CTc/postgres
(4 rows)
```

```bash
vagrant@node2:~$ sudo -u postgres psql
psql (16.14 (Ubuntu 16.14-0ubuntu0.24.04.1))
Type "help" for help.

postgres=# \l
                                                       List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | ICU Locale | ICU Rules |   Access privileges   
-----------+----------+----------+-----------------+-------------+-------------+------------+-----------+-----------------------
 otus_test | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | 
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | 
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | =c/postgres          +
           |          |          |                 |             |             |            |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |            |           | =c/postgres          +
           |          |          |                 |             |             |            |           | postgres=CTc/postgres
(4 rows)
```

## Проверка бэкапа

```bash
barman@barman:~$ barman cron 
Starting WAL archiving for server node1
barman@barman:~$ barman check node1
Server node1:
	PostgreSQL: OK
	superuser or standard user with backup privileges: OK
	PostgreSQL streaming: OK
	wal_level: OK
	replication slot: OK
	directories: OK
	retention policy settings: OK
	backup maximum age: FAILED (interval provided: 4 days, latest backup age: No available backups)
	backup minimum size: OK (0 B)
	wal maximum age: OK (no last_wal_maximum_age provided)
	wal size: OK (0 B)
	compression settings: OK
	failed backups: OK (there are 0 failed backups)
	minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
	pg_basebackup: OK
	pg_basebackup compatible: OK
	pg_basebackup supports tablespaces mapping: OK
	systemid coherence: OK (no system Id stored on disk)
	pg_receivexlog: OK
	pg_receivexlog compatible: OK
	receive-wal running: OK
	archiver errors: OK
barman@barman:~$ barman backup node1
Starting backup using postgres method for server node1 in /var/lib/barman/node1/base/20260603T032823
Backup start at LSN: 0/10000060 (000000010000000000000010, 00000060)
Starting backup copy via pg_basebackup for 20260603T032823
WARNING: pg_basebackup does not copy the PostgreSQL configuration files that reside outside PGDATA. Please manually backup the following files:
	/etc/postgresql/16/main/postgresql.conf
	/etc/postgresql/16/main/pg_hba.conf
	/etc/postgresql/16/main/pg_ident.conf

Copy done (time: less than one second)
Finalising the backup.
This is the first backup for server node1
WAL segments preceding the current backup have been found:
	00000001000000000000000E from server node1 has been removed
	00000001000000000000000F from server node1 has been removed
Backup size: 44.0 MiB
Backup end at LSN: 0/12000000 (000000010000000000000011, 00000000)
Backup completed (start time: 2026-06-03 03:28:23.993012, elapsed time: 1 second)
Processing xlog segments from streaming for node1
	000000010000000000000010
	000000010000000000000011
```