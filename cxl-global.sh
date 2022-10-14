#!/bin/bash
#
# Global functions commonly used for CXL-memory emulation
#
# Huaicheng Li <lhcwhu@gmail.com>
#

source /users/hcli/proj/run/run-globals.sh

#-------------------------------------------------------------------------------

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

flush_fs_caches()
{
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1
    sleep 10
}

disable_nmi_watchdog()
{
    echo 0 | sudo tee /proc/sys/kernel/nmi_watchdog >/dev/null 2>&1
}

disable_turbo()
{
    echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1
}

# 0: no randomization, everyting is static
# 1: conservative randomization, shared libraries, stack, mmap(), VDSO and heap
# are randomized
# 2: full randomization, the above points in 1 plus brk()
disable_va_aslr()
{
    echo 0 | sudo tee /proc/sys/kernel/randomize_va_space >/dev/null 2>&1
}

disable_swap()
{
    sudo swapoff -a
}

disable_ksm()
{
    echo 0 | sudo tee /sys/kernel/mm/ksm/run >/dev/null 2>&1
}

disable_numa_balancing()
{
    echo 0 | sudo tee /proc/sys/kernel/numa_balancing >/dev/null 2>&1
}

# disable transparent hugepages
disable_thp()
{
    echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1
}

enable_turbo()
{
    echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1
}

disable_ht()
{
    echo off | sudo tee /sys/devices/system/cpu/smt/control >/dev/null 2>&1
}

disable_node1_cpus()
{
    echo 0 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1
}

bring_all_cpus_online()
{
    echo 1 | sudo tee /sys/devices/system/cpu/cpu*/online >/dev/null 2>&1
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

check_pmqos()
{
    local pmqospid=$(ps -ef | grep pmqos | grep -v grep | grep -v sudo | awk '{print $2}')
    #echo $pmqospid

    set_performance_mode
    [[ -n "$pmqospid" ]] && return

    sudo nohup ${TOPDIR}/pmqos >/dev/null 2>&1 &
    sleep 3
    # double check
    pmqospid=$(ps -ef | grep pmqos | grep -v grep | grep -v sudo | awk '{print $2}')
    if [[ -z "$pmqospid" ]]; then
        echo "==> Error: failed to start pmqos!!!!"
        exit
    fi
}

# Keep all cores on Node 0 online while keeping all cores on Node 1 offline
configure_cxl_exp_cores()
{
    # To be safe, let's bring all the cores online first
    echo 1 | sudo tee /sys/devices/system/cpu/cpu*/online >/dev/null 2>&1

    # Disable all cores on Node 1
    echo 0 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1
}

configure_base_exp_cores()
{
    # To be safe, let's bring all the cores online first
    echo 1 | sudo tee /sys/devices/system/cpu/cpu*/online >/dev/null 2>&1
    # Leave half of the cores online for both Node 0 and Node 1
	local cores_per_socket=$(lscpu | grep -i 'Core(s) per socket' | awk '{print $4}')
    local half_cores_per_socket=$((cores_per_socket / 2))
    local total_cores=$((cores_per_socket * 2))
    for ((i = half_cores_per_socket; i < cores_per_socket; i++)); do
        echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online >/dev/null 2>&1
    done

    for ((i = cores_per_socket + half_cores_per_socket; i < total_cores; i++)); do
        echo 0 | sudo tee /sys/devices/system/cpu/cpu$i/online >/dev/null 2>&1
    done
}

check_base_conf()
{
    disable_nmi_watchdog
    disable_va_aslr
    disable_ksm
    disable_numa_balancing
    disable_thp
    disable_ht
    disable_turbo
    configure_base_exp_cores
    check_pmqos
    disable_swap

    nc=$(sudo numactl --hardware | grep 'node 1 cpus' | awk -F: '{print $2}')

    # Everything looks correct
    [[ ! -z $nc ]] && return

    # Bummer, let's try bring the cores on Node 1 up...
    echo "===> Warning: Base experiment environment NOT properly setup"
    echo "     All cores on Node 1 are offline..."

    echo "===> Enabling all the cores on Node 1 now ..."
    echo 1 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1

    nc=$(sudo numactl --hardware | grep 'node 1 cpus' | awk -F: '{print $2}')
    [[ -z $nc ]] && echo "===> Failed to bring up all the cores on Node 1 for Base experiments ..." && exit

    sleep 60
}

check_cxl_conf()
{
    disable_nmi_watchdog
    disable_va_aslr
    disable_ksm
    disable_numa_balancing
    disable_thp
    disable_ht
    disable_turbo
    configure_cxl_exp_cores
    check_pmqos
    disable_swap

    nc=$(sudo numactl --hardware | grep 'node 1 cpus' | awk -F: '{print $2}')

    # Everything looks correct
    [[ -z $nc ]] && return

    # Bummer, for CXL-emulation, let's take the cores on Node 1 offline...
    echo "===> Warning: CXL experiment environment NOT properly setup"
    echo "     I see online cores [$nc] on Node 1..."

    echo "===> Disabling all the cores on Node 1 now ..."
    echo 0 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1

    nc=$(sudo numactl --hardware | grep 'node 1 cpus' | awk -F: '{print $2}')
    [[ ! -z $nc ]] && echo "===> Failed to disable all the cores on Node 1 for CXL experiments ..." && exit

    sleep 60
}

reset_base() {
    disable_nmi_watchdog
    disable_va_aslr
    disable_ksm
    disable_numa_balancing
    disable_thp
    disable_ht
    disable_turbo
    configure_cxl_exp_cores
    check_pmqos

    # make sure all cores are online
    bring_all_cpus_online
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


#-------------------------------------------------------------------------------
# For Emon Run
#-------------------------------------------------------------------------------

# $1: CXL experiment type array, EXL_EXPARR, (pass array by name!)
# $2: Base experiment type array
# $3: Result directory
init_emon_profiling()
{
    # Attention: we are passing array name, and need convert it into an internal
    # array format
    local cxl_exparr_name=$1[@]
    local cxl_exparr=( "${!cxl_exparr_name}" )
    local base_exparr_name=$2[@]
    local base_exparr=( "${!base_exparr_name}" )
    local rstdir=$3

    mkdir -p $rstdir

    # CXL
    for ((et = 0; et < ${#cxl_exparr[@]}; et++)); do
        e=${cxl_exparr[$et]}
        if [[ $e == "L100" ]]; then
            run_cmd="numactl --cpunodebind 0 --membind 0 -- bash ./cmd.sh"
        elif [[ $e == "L0" ]]; then
            run_cmd="numactl --cpunodebind 0 --membind 1 -- bash ./cmd.sh"
        elif [[ $e == "CXL-Interleave" ]]; then
            run_cmd="numactl --cpunodebind 0 --interleave=all -- bash ./cmd.sh"
        else
            echo "==> Error: unsupported experiment type: [$e]"
            exit
        fi

        echo "${run_cmd}" > emon-$e.sh
        chmod u+x emon-$e.sh
        # Keep one copy for record
        cat cmd.sh > $rstdir/emon-${e}.cmd
        cat emon-$e.sh >> $rstdir/emon-${e}.cmd
    done

    # BASE
    for ((et = 0; et < ${#base_exparr[@]}; et++)); do
        e=${base_exparr[$et]}
        if [[ $e == "Base-Interleave" ]]; then
            run_cmd="numactl --interleave=all -- bash ./cmd.sh"
        else
            echo "==> Error: unsupported experiment type: [$et]"
            exit
        fi

        echo "${run_cmd}" > emon-$e.sh
        chmod u+x emon-$e.sh
        # Keep one copy for record
        cat cmd.sh > $rstdir/emon-${e}.sh
        cat emon-$e.sh >> $rstdir/emon-${e}.sh
    done
}

# $1: CXL experiment type array, EXL_EXPARR, (pass array by name!)
# $2: Base experiment type array
cleanup_emon_profiling()
{
    # Attention: we are passing array name, and need convert it into an internal
    # array format
    local cxl_exparr_name=$1[@]
    local cxl_exparr=( "${!cxl_exparr_name}" )
    local base_exparr_name=$2[@]
    local base_exparr=( "${!base_exparr_name}" )

    # CXL
    for ((et = 0; et < ${#cxl_exparr[@]}; et++)); do
        e=${cxl_exparr[$et]}
        rm -rf emon-$e.sh
    done

    # BASE
    for ((et = 0; et < ${#base_exparr[@]}; et++)); do
        e=${base_exparr[$et]}
        rm -rf emon-$e.sh
    done
}

# Run emon for one workload
# $1: experiment type, e.g. "L100", "CXL-Interleave", etc.
# $2: experiment id, e.g., "1", "2", etc.
# $3: result directory
# $4: memory footprint in MB (for running more splits)
run_emon_one()
{
    local e=$1
    local id=$2
    local rstdir=$3
    local m=$4

    # log files
    local sysinfof=$rstdir/${e}-${id}-emon.sysinfo
    local pidstatf=$rstdir/${e}-${id}-emon.pidstat
    local memf=$rstdir/${e}-${id}-emon.mem

    local emonvf=$rstdir/${e}-${id}-emon.v
    local emonmf=$rstdir/${e}-${id}-emon.m
    local emondatf=$rstdir/${e}-${id}-emon.dat

    local epid

    flush_fs_caches

    get_sysinfo > $sysinfof 2>&1
    sudo ${EMON} -v > $emonvf
    sudo ${EMON} -M > $emonmf

    # if needed, run memeater first
    # TODO ...

    # Run emon along with the workload
    ./emon-${e}.sh > $rstdir/out-${e}-${id} &

    local c=$(basename ${PWD} | awk -F- '{print $1}')
    epid=$!
    #epid=$(ps -ef | grep "${GAPBS_DIR}/$c" | grep -v grep | awk '{print $2}')
    echo "    => $e"

    sudo ${EMON} -i ${EMON_EVENT_FILE} -f "$emondatf" >/dev/null 2>&1 &
    pidstat -r -u -d -l -v -T ALL -p ALL -U -h 5 1000000 > $pidstatf &
    echo "Date Time Node0-Free-Mem-MB Node1-Free-Mem-MB" > $memf
    monitor_resource_util >>$memf 2>&1 &
    mpid=$!
    disown $mpid # avoid the "killed" message

    wait $epid
    sudo $EMON -stop
    killall pidstat >/dev/null 2>&1
    kill -9 $mpid >/dev/null 2>&1
}

# $1: "CXL" or "Base"
# $2: Experiment type array
# $3: Experiment id
# $4: Result directory
# $5: Memory footprint in MB (for running more splits)
run_emon_all()
{
    # Attention: we are passing array name, and need convert it into an internal
    # array format
    local exparr_name=$2[@]
    local exparr=( "${!exparr_name}" )
    local id=$3
    local rstdir=$4
    local m=$5

    if [[ $1 == "CXL" ]]; then
        check_cxl_conf
    elif [[ $1 == "BASE" ]]; then
        check_base_conf
    else
        echo ""
        echo "===> Error: only support CXL or Base!"
        echo ""
        exit
    fi

    mkdir -p $rstdir
    sudo $EMON -v > $rstdir/emon-v.dat
    sudo $EMON -M > $rstdir/emon-m.dat

    # CXL emon profiling

    for ((et = 0; et < ${#exparr[@]}; et++)); do
        run_emon_one "${exparr[$et]}" "${id}" "${rstdir}" "${m}"
    done
}

