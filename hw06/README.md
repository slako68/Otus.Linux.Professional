>## Цель домашнего задания:

## Размещаем свой RPM в своем репозитории.

>## Описание домашнего задания:

1) Создать свой RPM пакет (можно взять свое приложение, либо собрать, например,
Apache с определенными опциями).
2) Создать свой репозиторий и разместить там ранее собранный RPM.



Развертываем окружение ([Vagrantfile](https://github.com/slako68/Otus.Linux.Professional/tree/main/hw06/Vagrantfile)):

```console
$ vagrant up

ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  N = 1
  (1..N).each do |i|  
    config.vm.define "host#{i}" do |node|
      node.vm.box = "cloud-image/fedora-42"
      node.vm.hostname = "host#{i}"
      node.vm.network "private_network", ip: "192.168.122.10#{i}"
      node.vm.synced_folder ".", "/vagrant"
      node.vm.provider :libvirt do |libvirt|
        libvirt.cpus = "1"
        libvirt.memory = "1024"
      end
    end
  end
end
```

## Создаем свой RPM пакет

Устанавливаем пакеты:

```console
# yum install -y wget rpmdevtools rpm-build createrepo yum-utils cmake gcc git nano
# mkdir rpm && cd rpm
# yumdownloader --source nginx
# yum-builddep nginx
```
Скачиваем исходный код модуля ngx_brotli:

```console
# cd /root
# git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
# cd ngx_brotli/deps/brotli
# mkdir out && cd out
```
Собираем модуль ngx_brotli:

```console
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..

cmake --build . --config Release -j 2 --target brotlienc
```

Добавляем указание на модуль:

```console
--add-module=/root/ngx_brotli \
```

Сборка RPM пакета:

```console
# cd ~/rpmbuild/SPECS/
# rpmbuild -ba nginx.spec -D 'debug_package %{nil}'
```

```console
# ll ../RPMS/x86_64/

-rw-r--r--. 1 root root   33339 Feb  7 12:18 nginx-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root 1249969 Feb  7 12:18 nginx-core-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root  903630 Feb  7 12:18 nginx-mod-devel-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root   21719 Feb  7 12:18 nginx-mod-http-image-filter-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root   33577 Feb  7 12:18 nginx-mod-http-perl-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root   20586 Feb  7 12:18 nginx-mod-http-xslt-filter-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root   56673 Feb  7 12:18 nginx-mod-mail-1.28.1-3.fc42.x86_64.rpm
-rw-r--r--. 1 root root   96035 Feb  7 12:18 nginx-mod-stream-1.28.1-3.fc42.x86_64.rpm
```

Копируем пакеты в общий каталог:

```console
# cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/
# cd ~/rpmbuild/RPMS/x86_64
```

Устанавливаем пакеты:

```console
# yum install *.rpm
# systemctl start nginx
# systemctl status nginx

● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/service.d
             └─10-timeout-abort.conf, 50-keep-warm.conf
     Active: active (running) since Sat 2026-02-07 12:27:52 UTC; 8s ago
 Invocation: d33a8f277a4d4ca2a256960c32cdd3e3
    Process: 14927 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 14929 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 14933 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 14934 (nginx)
      Tasks: 2 (limit: 1079)
     Memory: 13.3M (peak: 13.5M)
        CPU: 119ms
     CGroup: /system.slice/nginx.service
             ├─14934 "nginx: master process /usr/sbin/nginx"
             └─14935 "nginx: worker process"
```

## Создаем свой репозиторий

```console
# mkdir /usr/share/nginx/html/repo
# cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/
# createrepo /usr/share/nginx/html/repo/

Directory walk started
Directory walk done - 10 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Pool started (with 5 workers)
Pool finished
```

```console
# curl -a http://localhost/repo/

<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          07-Feb-2026 12:32                   -
<a href="nginx-1.28.1-3.fc42.x86_64.rpm">nginx-1.28.1-3.fc42.x86_64.rpm</a>                     07-Feb-2026 12:32               33339
<a href="nginx-all-modules-1.28.1-3.fc42.noarch.rpm">nginx-all-modules-1.28.1-3.fc42.noarch.rpm</a>         07-Feb-2026 12:32               10325
<a href="nginx-core-1.28.1-3.fc42.x86_64.rpm">nginx-core-1.28.1-3.fc42.x86_64.rpm</a>                07-Feb-2026 12:32             1249969
<a href="nginx-filesystem-1.28.1-3.fc42.noarch.rpm">nginx-filesystem-1.28.1-3.fc42.noarch.rpm</a>          07-Feb-2026 12:32               12113
<a href="nginx-mod-devel-1.28.1-3.fc42.x86_64.rpm">nginx-mod-devel-1.28.1-3.fc42.x86_64.rpm</a>           07-Feb-2026 12:32              903630
<a href="nginx-mod-http-image-filter-1.28.1-3.fc42.x86_64.rpm">nginx-mod-http-image-filter-1.28.1-3.fc42.x86_6..&gt;</a> 07-Feb-2026 12:32               21719
<a href="nginx-mod-http-perl-1.28.1-3.fc42.x86_64.rpm">nginx-mod-http-perl-1.28.1-3.fc42.x86_64.rpm</a>       07-Feb-2026 12:32               33577
<a href="nginx-mod-http-xslt-filter-1.28.1-3.fc42.x86_64.rpm">nginx-mod-http-xslt-filter-1.28.1-3.fc42.x86_64..&gt;</a> 07-Feb-2026 12:32               20586
<a href="nginx-mod-mail-1.28.1-3.fc42.x86_64.rpm">nginx-mod-mail-1.28.1-3.fc42.x86_64.rpm</a>            07-Feb-2026 12:32               56673
<a href="nginx-mod-stream-1.28.1-3.fc42.x86_64.rpm">nginx-mod-stream-1.28.1-3.fc42.x86_64.rpm</a>          07-Feb-2026 12:32               96035
</pre><hr></body>
</html>
```
Добаляем репозиторий в /etc/yum.repos.d:

```console
# cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
```

Убедимся:

```console
# yum repolis | grep otus
otus                       otus-linux
```

Добавим пакет

```console
# cd /usr/share/nginx/html/repo/
# wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
```

Обновим список пакетов в репозитории:

```console
# createrepo /usr/share/nginx/html/repo/
# yum makecache
# yum list | grep otus
# yum install -y percona-release.noarch

Updating and loading repositories:
Repositories loaded.
Package                                                 Arch          Version                                                 Repository                          Size
Installing:
 percona-release                                        noarch        1.0-32                                                  otus                            50.3 KiB

Transaction Summary:
 Installing:         1 package

Total size of inbound packages is 28 KiB. Need to download 28 KiB.
After this operation, 50 KiB extra will be used (install 50 KiB, remove 0 B).
[1/1] percona-release-0:1.0-32.noarch                                                                                         100% |   1.2 MiB/s |  27.9 KiB |  00m00s
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
[1/1] Total                                                                                                                   100% |   1.1 MiB/s |  27.9 KiB |  00m00s
Running transaction
[1/3] Verify package files                                                                                                    100% |  83.0   B/s |   1.0   B |  00m00s
[2/3] Prepare transaction                                                                                                     100% |  27.0   B/s |   1.0   B |  00m00s
[3/3] Installing percona-release-0:1.0-32.noarch                                                                              100% |  29.3 KiB/s |  51.2 KiB |  00m02s
>>> Running post-install scriptlet: percona-release-0:1.0-32.noarch                                                                                                   
>>> Finished post-install scriptlet: percona-release-0:1.0-32.noarch                                                                                                  
>>> Scriptlet output:                                                                                                                                                 
>>> * Enabling the Percona Release repository                                                                                                                         
>>> <*> All done!                                                                                                                                                     
>>> * Enabling the Percona Telemetry repository                                                                                                                       
>>> <*> All done!                                                                                                                                                     
>>> * Enabling the PMM2 Client repository                                                                                                                             
>>> <*> All done!                                                                                                                                                     
>>> The percona-release package now contains a percona-release script that can enable additional repositories for our newer products.                                 
>>>                                                                                                                                                                   
>>> Note: currently there are no repositories that contain Percona products or distributions enabled. We recommend you to enable Percona Distribution repositories ins
>>>                                                                                                                                                                   
>>> For example, to enable the Percona Distribution for MySQL 8.0 repository use:                                                                                     
>>>                                                                                                                                                                   
>>>   percona-release setup pdps8.0                                                                                                                                   
>>>                                                                                                                                                                   
>>> Note: To avoid conflicts with older product versions, the percona-release setup command may disable our original repository for some products.                    
>>>                                                                                                                                                                   
>>> For more information, please visit:                                                                                                                               
>>>   https://docs.percona.com/percona-software-repositories/percona-release.html                                                                                     
>>>                                                                                                                                                                   
>>>                                                                                                                                                                   
Warning: skipped OpenPGP checks for 1 package from repository: otus
Complete!
```
