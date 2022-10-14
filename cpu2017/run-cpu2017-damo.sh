#!/bin/bash

DAMODIR=/users/hcli/git/damo
DAMORSTDIR=$(pwd)/rst/damo

echo $DAMORSTDIR
#exit
mkdir -p $DAMORSTDIR

check_va_aslr() {
    local VAL=$(cat /proc/sys/kernel/randomize_va_space)
    if [[ $VAL != 0 ]]; then
        echo ""
        echo "VA ASLR is on, disabling it now ..."
        /proj/nestfarm-PG0/disable-va-aslr.sh 2>&1 >/dev/null
    fi
}

check_va_aslr

for w in $(cat w.txt); do
    cd $w
    echo "===> Running $w w/ DAMON"
    PROG=$(cat cmd.sh | tail -n 1 | awk '{print $1}' | awk -F/ '{print $2}')

    killall $PROG 2>/dev/null
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
    sleep 5
    numactl --cpunodebind 0 --membind 0 -- ./cmd.sh &
    #sleep .5
    # proactively wait for the target process to start up
    while [[ -z $(ps -ef | grep $PROG | grep -v grep) ]]; do
        continue
    done

    PID=$(ps -ef | grep $PROG | grep -v grep | awk '{print $2}')
    #PIDD=$(pidof $PROG)
    echo "    ==> CMD: [$(ps -ef | grep $PROG | grep -v grep)]"

    # blocking here
    time sudo $DAMODIR/damo record -s 1000 -a 100000 -u 1000000 -n 1024 -m 1024 -o $DAMORSTDIR/$w.damo $PID

    #echo "$w: $PID, $(ps -ef | grep $PID | grep -v grep)"
    #sudo cat /proc/$PIDD/cmdline
    #for i in $PID; do
    #    kill -9 $i
    #done

    cd ../
    killall $PROG 2>/dev/null
done
