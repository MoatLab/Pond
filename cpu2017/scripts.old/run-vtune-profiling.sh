#!/bin/bash

VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"

# 1, -app-working-dir /users/hcli/proj/n
# performance-snapshot

RSTDIR="vtune-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
echo $RSTDIR
mkdir -p $RSTDIR

drop_caches()
{
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
    sleep 10
}

e=1
CMD_L100="numactl --cpunodebind 0 --membind 0 -- bash ./cmd.sh"
CMD_L0="numactl --cpunodebind 0 --membind 1 -- bash ./cmd.sh"
CMD_L50="numactl --interleave=all --cpunodebind 0 -- bash ./cmd.sh"

echo '#!/bin/bash' > L100.sh
echo '#!/bin/bash' > L50.sh
echo '#!/bin/bash' > L0.sh
echo "${CMD_L100}" >> L100.sh
echo "${CMD_L50}" >> L50.sh
echo "${CMD_L0}" >> L0.sh
chmod u+x L{100,50,0}.sh

profile_macc()
{
    # 100
    drop_caches
    # -knob analyze-mem-objects=true
    sudo $VTUNE -collect memory-access -knob sampling-interval=100 -r $RSTDIR/L100-macc-$e -- ./L100.sh

    # 50
    drop_caches
    sudo $VTUNE -collect memory-access -knob sampling-interval=100 -r $RSTDIR/L50-macc-$e -- ./L50.sh

    # 0
    drop_caches
    # -knob analyze-mem-objects=true
    sudo $VTUNE -collect memory-access -knob sampling-interval=100 -r $RSTDIR/L0-macc-$e -- ./L0.sh
}

profile_uarch()
{
    drop_caches
    sudo $VTUNE -collect uarch-exploration -knob sampling-interval=100 -knob collect-memory-bandwidth=true -r $RSTDIR/L100-uarch-$e -- ./L100.sh

    drop_caches
    sudo $VTUNE -collect uarch-exploration -knob sampling-interval=100 -knob collect-memory-bandwidth=true -r $RSTDIR/L50-uarch-$e -- ./L50.sh

    drop_caches
    sudo $VTUNE -collect uarch-exploration -knob sampling-interval=100 -knob collect-memory-bandwidth=true -r $RSTDIR/L0-uarch-$e -- ./L0.sh
}


profile_macc
profile_uarch


exit
exit
exit



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

