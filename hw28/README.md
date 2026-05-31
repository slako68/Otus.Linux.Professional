## Цель домашнего задания:

- Поработать с реаликацией MySQL.

## Описание домашнего задания:

- Базу развернуть на мастере и настроить так, чтобы реплицировались таблицы;
- Настроить GTID репликацию.

## Vagrantfile
```bash
# -*- mode: ruby -*-
# vim: set ft=ruby :

MACHINES = {
  :master => {
        :box_name => "bento/centos-stream-9",
        :vm_name => "master",
        :ip_addr => '192.168.11.150'
  },
  :slave => {
        :box_name => "bento/centos-stream-9",
        :vm_name => "slave",
        :ip_addr => '192.168.11.151'
  }
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

      config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s

          box.vm.network "private_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
            vb.customize ["modifyvm", :id, "--memory", "1024"]
          end

          box.vm.provision :shell do |s|
             s.inline = 'mkdir -p ~root/.ssh; cp ~vagrant/.ssh/auth* ~root/.ssh'
          end
          if boxconfig[:vm_name] == "slave"
            box.vm.provision "ansible" do |ansible|
              ansible.playbook = "provision.yml"
              ansible.inventory_path = "hosts"
              ansible.host_key_checking = "false"
              ansible.become = "true"
              ansible.limit = "all"
            end
          end
      end
  end
end
```

## ansible provision

```bash
- name: Base set up
  hosts: all
  become: yes
  tasks:

    - name: install percona
      ansible.builtin.shell: yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm

    - name: install percona
      ansible.builtin.shell: percona-release enable-only ps-84-lts release

    - name: install percona
      ansible.builtin.shell: PERCONA_TELEMETRY_DISABLE=1 yum install -y percona-server-server

    - name: Copy directory contents to remote host
      ansible.builtin.copy:
        src: conf/conf.d/
        dest: /etc/my.cnf.d/
        owner: root
        group: root
        mode: '0644'

    - name: Insert line after a specific pattern
      ansible.builtin.lineinfile:
        path: /etc/my.cnf
        line: "!includedir /etc/my.cnf.d/"

    - name: Permit traffic for 3306/tcp
      ansible.posix.firewalld:
        port: 3306/tcp
        permanent: true
        immediate: true
        state: enabled

    - name: Start and enable mysql
      ansible.builtin.systemd:
        name: mysql
        state: started
        enabled: yes
```

## Настройка репликации на master

```bash
sudo cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $13}'
mysql> ALTER USER USER() IDENTIFIED BY '1qaz!QAZ';
mysql> SELECT @@server_id;
mysql> SHOW VARIABLES LIKE 'gtid_mode';
mysql> CREATE DATABASE bet;
mysql -u root -p -D bet < /vagrant/bet.dmp
mysql> USE bet;
mysql> SHOW TABLES;
mysql> CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY '!OtusLinux2018';
mysql> SELECT user,host FROM mysql.user where user='repl';
mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
mysqldump --all-databases --triggers --routines --source-data --ignore-table=bet.events_on_demand --ignore-table=bet.v_same_event -u root -p > master.sql
```

## Настройка репликации на slave

```bash
sudo vi /etc/my.cnf.d/01-base.cnf (server-id = 2)
sudo vi /etc/my.cnf.d/05-binlog.cnf (раскомментировать таблицы)
sudo cat /var/log/mysqld.log | grep 'root@localhost:' | awk '{print $13}'
mysql> ALTER USER USER() IDENTIFIED BY '1qaz!QAZ';
sudo systemctl restart mysql
mysql> SELECT @@server_id;
mysql> SOURCE /vagrant/master.sql
mysql> SHOW DATABASES LIKE 'bet';
mysql> USE bet;
mysql> SHOW TABLES;
mysql> CHANGE REPLICATION SOURCE TO
  SOURCE_HOST = '192.168.11.150',
  SOURCE_PORT = 3306,
  SOURCE_USER = 'repl',
  SOURCE_PASSWORD = '!OtusLinux2018',
  SOURCE_AUTO_POSITION = 1;
mysql> START REPLICA;
```

```bash
mysql> SHOW REPLICA STATUS\G
*************************** 1. row ***************************
             Replica_IO_State: Waiting for source to send event
                  Source_Host: 192.168.11.150
                  Source_User: repl
                  Source_Port: 3306
                Connect_Retry: 60
              Source_Log_File: mysql-bin.000002
          Read_Source_Log_Pos: 121357
               Relay_Log_File: slave-relay-bin.000002
                Relay_Log_Pos: 422
        Relay_Source_Log_File: mysql-bin.000002
           Replica_IO_Running: Yes
          Replica_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Source_Log_Pos: 121357
              Relay_Log_Space: 633
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Source_SSL_Allowed: No
           Source_SSL_CA_File: 
           Source_SSL_CA_Path: 
              Source_SSL_Cert: 
            Source_SSL_Cipher: 
               Source_SSL_Key: 
        Seconds_Behind_Source: 0
Source_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Source_Server_Id: 1
                  Source_UUID: e21c02f3-5d10-11f1-bb22-080027adf695
             Source_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
    Replica_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Source_Retry_Count: 10
                  Source_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Source_SSL_Crl: 
           Source_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: e21c02f3-5d10-11f1-bb22-080027adf695:1-43,
e23b4e89-5d10-11f1-bafa-080027adf695:1
                Auto_Position: 1
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Source_TLS_Version: 
       Source_public_key_path: 
        Get_Source_public_key: 0
            Network_Namespace: 
1 row in set (0.00 sec)
```

## Проверка репликации

### На master

```bash
mysql> USE bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed

mysql> INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet');
Query OK, 1 row affected (0.02 sec)

mysql> SELECT * FROM bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)

mysql> exit
Bye
[vagrant@master ~]$ 
```

 ### На slave

 ```bash
mysql> SELECT * FROM bookmaker
    -> ;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)

mysql> exit
Bye
[vagrant@slave ~]$
 ```

 ```bash
[vagrant@slave ~]$ sudo mysqlbinlog /var/lib/mysql/mysql-bin.000003
# The proper term is pseudo_replica_mode, but we use this compatibility alias
# to make the statement usable on server versions 8.0.24 and older.
/*!50530 SET @@SESSION.PSEUDO_SLAVE_MODE=1*/;
/*!50003 SET @OLD_COMPLETION_TYPE=@@COMPLETION_TYPE,COMPLETION_TYPE=0*/;
DELIMITER /*!*/;
# at 4
#260531 17:13:37 server id 2  end_log_pos 127 CRC32 0xe6efce3e 	Start: binlog v 4, server v 8.4.8-8 created 260531 17:13:37 at startup
# Warning: this binlog is either in use or was not closed properly.
ROLLBACK/*!*/;
BINLOG '
QWwcag8CAAAAewAAAH8AAAABAAQAOC40LjgtOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAABBbBxqEwANAAgAAAAABAAEAAAAYwAEGggAAAAAAAACAAAACgoKKioAEjQA
CigAAAE+zu/m
'/*!*/;
# at 127
#260531 17:13:37 server id 2  end_log_pos 198 CRC32 0x25d1bb9a 	Previous-GTIDs
# e23b4e89-5d10-11f1-bafa-080027adf695:1
# at 198
#260531 17:24:00 server id 1  end_log_pos 284 CRC32 0x4fceb28a 	GTID	last_committed=0	sequence_number=1	rbr_only=no	original_committed_timestamp=1780248240167172	immediate_commit_timestamp=1780248240177281	transaction_length=323
# original_commit_timestamp=1780248240167172 (2026-05-31 17:24:00.167172 UTC)
# immediate_commit_timestamp=1780248240177281 (2026-05-31 17:24:00.177281 UTC)
/*!80001 SET @@session.original_commit_timestamp=1780248240167172*//*!*/;
/*!80014 SET @@session.original_server_version=80408*//*!*/;
/*!80014 SET @@session.immediate_server_version=80408*//*!*/;
SET @@SESSION.GTID_NEXT= 'e21c02f3-5d10-11f1-bb22-080027adf695:44'/*!*/;
# at 284
#260531 17:24:00 server id 1  end_log_pos 360 CRC32 0x6863f073 	Query	thread_id=16	exec_time=0	error_code=0
SET TIMESTAMP=1780248240/*!*/;
SET @@session.pseudo_thread_id=16/*!*/;
SET @@session.foreign_key_checks=1, @@session.sql_auto_is_null=0, @@session.unique_checks=1, @@session.autocommit=1/*!*/;
SET @@session.sql_mode=1168113696/*!*/;
SET @@session.auto_increment_increment=1, @@session.auto_increment_offset=1/*!*/;
/*!\C utf8mb4 *//*!*/;
SET @@session.character_set_client=255,@@session.collation_connection=255,@@session.collation_server=255/*!*/;
SET @@session.lc_time_names=0/*!*/;
SET @@session.collation_database=DEFAULT/*!*/;
/*!80011 SET @@session.default_collation_for_utf8mb4=255*//*!*/;
BEGIN
/*!*/;
# at 360
#260531 17:24:00 server id 1  end_log_pos 490 CRC32 0xf43aa88d 	Query	thread_id=16	exec_time=0	error_code=0
use `bet`/*!*/;
SET TIMESTAMP=1780248240/*!*/;
INSERT INTO bookmaker (id,bookmaker_name) VALUES(1,'1xbet')
/*!*/;
# at 490
#260531 17:24:00 server id 1  end_log_pos 521 CRC32 0x0dfe50d2 	Xid = 700
COMMIT/*!*/;
SET @@SESSION.GTID_NEXT= 'AUTOMATIC' /* added by mysqlbinlog */ /*!*/;
DELIMITER ;
# End of log file
/*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/;
/*!50530 SET @@SESSION.PSEUDO_SLAVE_MODE=0*/;
 ```