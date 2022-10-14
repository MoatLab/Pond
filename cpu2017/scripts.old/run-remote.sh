#!/bin/bash
#
# Run Caspian CXL-memory experiments
#

# Reserve newlines during command substitution
#IFS=

#warr=($(cat w.txt))
#echo ${warr[@]}

# Suppose the host server has 2 nodes, [Node 1: 8c/32g + Node 2: 8c/32g]

# (1).
# Emulated CXL-memory cases
# (N1:8c/32g + N2:0c/32g)
# "100" -> 100% local memory configuration
# "50"  -> 50% local memory
# "0"   -> 0% local memory

# (2).
# NUMA baseline cases
# (N1:8c/32g + N2:8c/32g)
# "Interleave" -> round robin memory allocation across NUMA nodes


TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"

RSTDIR="rst-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"


if [[ ! -e /usr/bin/time ]]; then
    echo "Please install GNU time first!"
    exit
fi

flush_fs_caches()
{
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
    sleep 5
}

disable_turbo()
{
    echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1
}

disable_ht()
{
    echo off | sudo tee /sys/devices/system/cpu/smt/control >/dev/null 2>&1
}

disable_node1_cpus()
{
    echo 0 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1
}

set_performance_mode()
{
    #echo "  ===> Placing CPUs in performance mode ..."
    for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee $governor >/dev/null 2>&1
    done
}

disable_node1_mem()
{
    echo 0 | sudo tee /sys/devices/system/node/node1/memory*/online >/dev/null 2>&1
}

check_cxl_conf()
{
    return
}

monitor_resource_util()
{
    while true; do
        local o=$(sudo numactl --hardware)
        local node0_free_mb=$(echo "$o" | grep "node 0 free" | awk '{print $4}')
		local node1_free_mb=$(echo "$o" | grep "node 1 free" | awk '{print $4}')
        echo "$(date +"%D %H%M%S") ${node0_free_mb} ${node1_free_mb}"
        #pidstat -r -u -d -l -p ALL -U -h 5 100000000 > pidstat.log &
        sleep 5
    done
}

get_sysinfo()
{
    uname -a
    echo "--------------------------"
    sudo numactl --hardware
    echo "--------------------------"
    lscpu
    echo "--------------------------"
    cat /proc/meminfo
}

# Must be called under the corresponding workload folder (e.g. 519.lbm_r/)
# $1 -> CLX exp type
# $2 -> Exp ID
# Require taking all CPUs on Node 1 offline
run_one_exp()
{
    local et=$1
    local id=$2
    local run_cmd="$(cat cmd.sh | grep -v "^#")"

    if [[ $et == "L100" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 0 -- ""${run_cmd}"
    elif [[ $et == "L0" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 1 -- ""${run_cmd}"
    elif [[ $et == "L50" ]]; then
        run_cmd="numactl --cpunodebind 0 --interleave=all -- ""${run_cmd}"
    fi

    [[ ! -d $RSTDIR ]] && mkdir -p $RSTDIR
    [[ ! -e $RSTDIR/sys.info ]] && get_sysinfo > $RSTDIR/sys.info 2>&1

    local logf=$RSTDIR/${et}-${id}.log
    local timef=$RSTDIR/${et}-${id}.time
    local output=$RSTDIR/${et}-${id}.output
    local memf=$RSTDIR/${et}-${id}.mem
    flush_fs_caches

    {
        echo "$run_cmd" | tee r.sh
        echo "Start: $(date)"
        /usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} bash r.sh >> $output 2>&1 &
        #/usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} sleep 15 >> $output 2>&1 &
        cpid=$!
        echo "Date Time Node0-Free-Mem-MB Node1-Free-Mem-MB" >$memf
        monitor_resource_util >>$memf 2>&1 &
        mpid=$!

        disown $mpid # avoid the "killed" message
        wait $cpid 2>/dev/null
        kill -9 $mpid >/dev/null 2>&1
        echo "End: $(date)"
        echo "" && echo "" && echo "" && echo ""
        rm -rf r.sh
    } >> $logf
}

# run "L100" "L50" "L0" in one shot
# $1: "workload"
# $2: id
run_one_workload()
{
    local w=$1
    local id=$2

    echo $w
    echo "===> Running $w L100 (id=$id), $(date)"
    # under workload folder now, start running logic
    run_one_exp "L100" $id
    echo "===> Running $w L50 (id=$id), $(date)"
    run_one_exp "L50" $id
    echo "===> Running $w L0 (id=$id), $(date)"
    run_one_exp "L0" $id
}

# Run one workload over a ssh'ed remote server
main()
{
    w=$1
    for i in 1 2 3; do
        echo "i=$i"
        run_one_workload $w $i
    done
}

if [[ $# != 1 ]]; then
    echo ""
    echo "Usage: $0 519.lbm_r"
    echo ""
    exit
fi

main "$@"
