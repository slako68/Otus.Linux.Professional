>## Цель домашнего задания:

- научиться создавать пользователей и добавлять им ограничения;

>## Описание домашнего задания:

Ограничить доступ к системе для всех пользователей, кроме группы администраторов, в выходные дни (суббота и воскресенье), за исключением праздничных дней.

### Vagrantfile

```bash
Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "host#{i}" do |node|
      node.vm.box = "cloud-image/ubuntu-26.04"
      node.vm.hostname = "host#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.network "forwarded_port", guest: 80, host: "8080"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "2"
        libvirt.memory = "2048"
      end
      node.vm.provision "shell", inline: <<-SHELL
        sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
        rm /etc/ssh/sshd_config.d/50-cloud-init.conf /etc/ssh/sshd_config.d/60-cloudimg-settings.conf 
        systemctl restart sshd.service
      SHELL
    end
  end
end

```
## ansible-playbook provision.yml -e pass=Otus2022!

```bash
---

- name: Add group admin
  ansible.builtin.group:
    name: admin
    state: present
    
- name: Add users
  vars:
    new_password: "{{ pass }}"
    users:
      - { name: 'vagrant', password: '{{ new_password | password_hash("sha512") }}', groups: 'admin' }
      - { name: 'root', password: '{{ new_password | password_hash("sha512") }}', groups: 'admin' }
      - { name: 'otusadm', password: '{{ new_password | password_hash("sha512") }}', groups: 'admin' }
      - { name: 'otus', password: '{{ new_password | password_hash("sha512") }}', groups: '' }
  user:
    name: "{{ item.name }}"
    password: "{{ item.password }}"
    groups: "{{ item.groups }}"
    append: yes
  loop: "{{ users }}"

- name: Copy /etc/pam.d/sshd
  ansible.builtin.copy:
    src: ../files/sshd
    dest: /etc/pam.d/sshd
    owner: root
    group: root
    mode: '0644'

- name: Copy /usr/local/bin/login.sh
  ansible.builtin.copy:
    src: ../files/login.sh
    dest: /usr/local/bin/login.sh
    owner: root
    group: root
    mode: '0755'

- name: Restart sshd
  ansible.builtin.service:
    name: sshd.service
    state: restarted
```

## Вход otusadm и не вход otus: 

```bash
otusadm@host1:~$ sudo journalctl -f
Apr 12 07:46:57 host1 systemd[1]: Stopped ssh.service - OpenBSD Secure Shell server.
Apr 12 07:46:57 host1 systemd[1]: ssh.service: Consumed 2.332s CPU time over 1min 5.196s wall clock time, 9.6M memory peak.
Apr 12 07:46:57 host1 systemd[1]: sshd-keygen.service - Generate sshd host keys on first boot skipped, unmet condition check ConditionFirstBoot=yes
Apr 12 07:46:57 host1 systemd[1]: Starting ssh.service - OpenBSD Secure Shell server...
Apr 12 07:46:57 host1 sshd[34126]: Server listening on 0.0.0.0 port 22.
Apr 12 07:46:57 host1 sshd[34126]: Server listening on :: port 22.
Apr 12 07:46:57 host1 systemd[1]: Started ssh.service - OpenBSD Secure Shell server.
Apr 12 07:46:57 host1 sudo[34117]: pam_unix(sudo:session): session closed for user root
Apr 12 07:47:03 host1 sudo[34199]: pam_unix(sudo:session): session opened for user root(uid=0) by otusadm(uid=1002)
Apr 12 07:47:03 host1 sudo[34199]: otusadm : TTY=/dev/pts/0 ; PWD=/home/otusadm ; USER=root ; COMMAND=/usr/bin/journalctl -f
Apr 12 07:47:10 host1 sshd-session[34205]: pam_exec(sshd:auth): Calling /usr/local/bin/login.sh ...
Apr 12 07:47:10 host1 sshd-session[34203]: pam_exec(sshd:auth): /usr/local/bin/login.sh failed: exit code 1
Apr 12 07:47:12 host1 sshd-session[34203]: Failed password for otus from 192.168.122.1 port 45706 ssh2
Apr 12 07:49:09 host1 sshd[34126]: Timeout before authentication for connection from 192.168.122.1 to 192.168.122.101, pid = 34203
```

## Доступ к docker

```bash
$ sudo usermod -aG docker otus
$ sudo -u otus -i
$ docker --version
Docker version 29.1.3, build 29.1.3-0ubuntu4
$ docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
$
```

## Право перезапускать docker сервис /etc/polkit-1/rules.d/01-dockerrestart.rules

```bash
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "docker.service" &&
        action.lookup("verb") == "restart" &&
        subject.user == "otus") {
        return polkit.Result.YES;
    }
});

$ sudo -u otus -i
$ systemctl restart docker

$ systemctl restart sshd
==== AUTHENTICATING FOR org.freedesktop.systemd1.manage-units ====
Authentication is required to restart 'ssh.service'.
Multiple identities can be used for authentication:
 1.  Ubuntu (ubuntu)
 2.  vagrant
 3.  otusadm
Choose identity to authenticate as (1-3): ^C
$
```