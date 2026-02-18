>## Цель домашнего задания:

- знать, что такое процесс, его атрибуты, жизненный цикл процесса;
- понимать, чем потоки отличаются от процессов;
- мониторить процессы, в каком они состоянии, понимать чем они сейчас заняты;
- использовать команды ps/top, подсистему /proc, а также команды gdb/strace/ltrace;
- менять приоритеты с мощью команд nice, ionice;
- посылать различные сигналы процессам.

>## Описание домашнего задания:

- реализовать 2 конкурирующих процесса по IO. пробовать запустить с разными ionice
Результат ДЗ - скрипт запускающий 2 процесса с разными ionice, замеряющий время выполнения и лог консоли
- реализовать 2 конкурирующих процесса по CPU. пробовать запустить с разными nice
Результат ДЗ - скрипт запускающий 2 процесса с разными nice и замеряющий время выполнения и лог консоли


## Скрипт

```console
#!/bin/bash

rm -f /tmp/file_{1,2}.dump >/dev/null 2>&1
rm -f /tmp/file_{1,2}.dump.tar.gz >/dev/null 2>&1

function ionice1 {
  ionice -c 2 dd if=/dev/urandom of=/tmp/file_1.dump bs=1M count=1024 >/dev/null 2>&1
}
function ionice2 {
  ionice -c 3 dd if=/dev/urandom of=/tmp/file_2.dump bs=1M count=1024 >/dev/null 2>&1
}
function nice1 {
  nice -n -20 tar czf /tmp/file_1.dump.tag.gz /tmp/file_1.dump >/dev/null 2>&1
}
function nice2 {
  nice -n 19 tar czf /tmp/file_2.dump.tag.gz /tmp/file_2.dump >/dev/null 2>&1
}

echo "ionice 2"
echo "ionice 3"

for i in {1..2}; do {
  time ionice$i &
  PID+=" $!"
} done
wait $PID

echo
echo "nice-20"
echo "nice 19"

for i in {1..2}; do {
  time nice$i &
  PID+=" $!"
} done
wait $PID
```

## Лог консоли

```
slako68@slako68-IFLTSI27P3S11:~/otus/Otus.Linux.Professional/hw10$ ./script.sh
ionice 2
ionice 3

real	0m3,670s
user	0m0,000s
sys     0m3,643s

real	0m3,687s
user	0m0,001s
sys     0m3,635s

nice-20
nice 19

real	0m34,903s
user	0m34,371s
sys     0m1,091s

real	0m35,134s
user	0m34,478s
sys     0m1,115s
```