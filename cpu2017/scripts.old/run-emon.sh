#!/bin/bash
#
# Run EMON profiling for one workload (must run under the workload folder!!)
#
# Huaicheng Li <lhcwhu@gmail.com>
#

TOPDIR="/users/hcli/proj/run"

VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"
EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"

# Source global functions
source $TOPDIR/cxl-global.sh || exit

# Output folder
RSTDIR="rst/emon-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
echo $RSTDIR

# Exp Id (only run once for profiling exp)
id=1

# Array of experiment types
CXL_EXPARR=("L100" "CXL-Interleave" "L0")
BASE_EXPARR=("Base-Interleave")

init_profiling()
{
    mkdir -p $RSTDIR
    # CXL
    for ((et = 0; et < ${#CXL_EXPARR[@]}; et++)); do
        e=${CXL_EXPARR[$et]}
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
        cp emon-$e.sh $RSTDIR/
    done

    # BASE
    for ((et = 0; et < ${#BASE_EXPARR[@]}; et++)); do
        e=${BASE_EXPARR[$et]}
        if [[ $e == "Base-Interleave" ]]; then
            run_cmd="numactl --interleave=all -- bash ./cmd.sh"
        else
            echo "==> Error: unsupported experiment type: [$et]"
            exit
        fi

        echo "${run_cmd}" > emon-$e.sh
        chmod u+x emon-$e.sh
        # Keep one copy for record
        cp emon-$e.sh $RSTDIR/
    done

}

cleanup_profiling()
{
    # CXL
    for ((et = 0; et < ${#CXL_EXPARR[@]}; et++)); do
        e=${CXL_EXPARR[$et]}
        rm -rf emon-$e.sh
    done

    # BASE
    for ((et = 0; et < ${#BASE_EXPARR[@]}; et++)); do
        e=${BASE_EXPARR[$et]}
        rm -rf emon-$e.sh
    done
}

# $1: "CXL" or "Base"
run_emon()
{

    if [[ $1 == "CXL" ]]; then
        EXPARR=( "${CXL_EXPARR[@]}" )
    elif [[ $1 == "BASE" ]]; then
        EXPARR=( "${BASE_EXPARR[@]}" )
    fi

    mkdir -p $RSTDIR
    sudo $EMON -v > $RSTDIR/emon-v.dat
    sudo $EMON -M > $RSTDIR/emon-m.dat

    # CXL emon profiling
    check_cxl_conf

    for ((et = 0; et < ${#EXPARR[@]}; et++)); do
        flush_fs_caches
        e=${EXPARR[$et]}
        local sysinfof=$RSTDIR/${e}-${id}-emon.sysinfo
        local pidstatf=$RSTDIR/${e}-${id}-emon.pidstat
        local emondatf=$RSTDIR/${e}-${id}-emon.dat
        local memf=$RSTDIR/${e}-${id}-emon.mem

        get_sysinfo > $sysinfof 2>&1
        ./emon-${e}.sh &
        pid=$!
        sudo $EMON -i ../clx-2s-events.txt -f "$emondatf" >/dev/null 2>&1 &
        pidstat -r -u -d -l -v -p $pid -U -h 1 1000000 > $pidstatf &
        echo "Date Time Node0-Free-Mem-MB Node1-Free-Mem-MB" > $memf
        monitor_resource_util >>$memf 2>&1 &
        mpid=$!
        disown $mpid # avoid the "killed" message

        wait $pid
        sudo $EMON -stop
        killall pidstat >/dev/null 2>&1
        kill -9 $mpid >/dev/null 2>&1
    done
}

main()
{
    #---------------------------------------------------------------------------
    # MAIN LOGIC HERE

    WARR=($(cat w6.txt))

    for ((i = 0; i < ${#WARR[@]}; i++)); do
        w=${WARR[$i]}
        cd $w
        init_profiling

        echo "==> Running $w ..."
        run_emon "CXL"
        run_emon "BASE"

        cleanup_profiling
        cd ../
    done
    #

    #---------------------------------------------------------------------------
    echo "===> All done (emon profiling)!"
}


main
