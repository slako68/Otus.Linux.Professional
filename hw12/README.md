>## Цель домашнего задания:

написать первые шаги с Ansible


>## Описание домашнего задания:

Подготовить стенд на Vagrant как минимум с одним сервером. На этом сервере, используя Ansible, необходимо развернуть nginx со следующими условиями:

- необходимо использовать модуль yum/apt;
- конфигурационные файлы должны быть взяты из шаблона jinja2 с переменными;
- после установки nginx должен быть в режиме enabled в systemd;
- должен быть использован notify для старта nginx после установки;
- сайт должен слушать на нестандартном порту — 8080, для этого использовать переменные в Ansible.

## Развертываем инфраструктуру на Vagrant (провайдер libvirt).

```console
MACHINES = {
  :nginx => {
        :box_name => "bento/ubuntu-24.04",
        :vm_name => "nginx",
        :net => [
           ["192.168.122.150",  2, "255.255.255.0", "mynet"],
        ]
  }
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

    config.vm.define boxname do |box|
   
      box.vm.box = boxconfig[:box_name]
      box.vm.host_name = boxconfig[:vm_name]
      
      box.vm.provider :libvirt do |libvirt|
        libvirt.cpus = 2
        libvirt.memory = 2048
        libvirt.forward_ssh_port = true
      end

      boxconfig[:net].each do |ipconf|
        box.vm.network("private_network", ip: ipconf[0])
      end

      if boxconfig.key?(:public)
        box.vm.network "public_network", boxconfig[:public]
      end

      box.vm.provision "shell", inline: <<-SHELL
        apt update
        DEBIAN_FRONTEND='noninteractive' apt-get -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' install openssh-server -y
      SHELL
      box.vm.provision "ansible" do |ansible|
        ansible.playbook = "nginx.yml"
      end
    end
  end
end
```

## Развертываем nginx (ansible provision)

```console
      box.vm.provision "ansible" do |ansible|
        ansible.playbook = "nginx.yml"
      end
```
## Используем модуль apt

```console
  tasks:
  - name: Install nginx
    ansible.builtin.apt:
      pkg:
      - nginx
      state: latest
      update_cache: yes
    tags:
    - nginx-package
    notify:
    - restart nginx
```

## Конфигурационные файлы должны берем из шаблона jinja2 

```console
  - name: NGINX | Create NGINX config file from template
    template:
      src: templates/nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    tags:
    - nginx-configuration
    notify:
    - reload nginx
```

## Используем notify для старта nginx после установки и релоад после обновления файла конфигурации

```console
    notify:
    - restart nginx

    notify:
    - reload nginx
```

```console
  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
        enabled: yes

    - name: reload nginx
      systemd:
        name: nginx
        state: reloaded

```

## Сайт слушает на нестандартном порту — 8080

```console
$ curl 192.168.122.150:8080

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```