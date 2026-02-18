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

