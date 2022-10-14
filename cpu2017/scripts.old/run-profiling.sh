#!/bin/bash

VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"

# 1, -app-working-dir /users/hcli/proj/n
# performance-snapshot


# first run, let's monitor its system-level resource util first
echo 3 | sudo tee /proc/sys/vm/drop_caches
sleep 10
./r.sh 0 &
pid=$!

pidstat -r -u -d -l -p ALL -U -h 5 100000000 > pidstat.log &
wait $pid
killall pidstat
echo 3 | sudo tee /proc/sys/vm/drop_caches
#sleep 30


exit

sudo $VTUNE -collect memory-access -r L100-macc -knob sampling-interval=100 -knob analyze-mem-objects=true -- ./r.sh 0
sleep 10
sudo $VTUNE -collect uarch-exploration -r L100-uarch -knob sampling-interval=100 -knob collect-memory-bandwidth=true -- ./r.sh 0
sleep 10

sudo $VTUNE -collect memory-access -r L0-macc -knob sampling-interval=100 -knob analyze-mem-objects=true -- ./r.sh 1
sleep 10
sudo $VTUNE -collect uarch-exploration -r L0-uarch -knob sampling-interval=100 -knob collect-memory-bandwidth=true -- ./r.sh 1
