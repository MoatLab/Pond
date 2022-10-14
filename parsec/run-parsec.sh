#!/bin/bash
#
# Run CXL-memory experiments for PARSEC workloads
#
# Huaicheng Li <lhcwhu@gmail.com>
#

EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"
RUNDIR="/users/hcli/proj/run"

# Output folder
MEMEATER="$RUNDIR/memeater"
PARSEC_RUN_DIR="${RUNDIR}/parsec"
RSTDIR="${PARSEC_RUN_DIR}/rst/"

RUN_EMON=0 # 1

# Reserve newlines during command substitution
#IFS=

if [[ $# != 1 && $# != 2 ]]; then
    echo ""
    echo "$0 wi.txt"
    echo "$0 w.txt 1"
    echo ""
    exit
fi

WF=$1
WID=$2

if [[ $# == 1 ]]; then
    warr=($(cat $WF | awk '{print $1}'))
    marr=($(cat $WF | awk '{print $2}'))
elif [[ $# == 2 ]]; then
    warr=($(cat w.txt | awk -vline=$WID 'NR == line {print $1}'))
    marr=($(cat w.txt | awk -vline=$WID 'NR == line {print $2}'))
fi
#warr=($(cat w8t.txt))
#echo ${warr[@]}
#echo ${marr[@]}

echo "==> Result directory: $RSTDIR"
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

# Source global functions
source $RUNDIR/cxl-global.sh || exit

[[ -e $EMON ]] || exit

TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"

if [[ ! -e /usr/bin/time ]]; then
    echo "Please install GNU time first!"
    exit
fi

# Must be called under the corresponding workload folder (e.g. 519.lbm_r/)
# $1: workload
# $2: exp type (L100, L50, L0, "CXL-Interleave")
# $3: exp ID
# $4: workload wss, required for running more splits (L95 -- L75)
# Require taking all CPUs on Node 1 offline
run_one_exp()
{
    local w=$1
    local et=$2
    local id=$3
    local mem=$4
    #local run_cmd="$(cat cmd.sh | grep -v "^#")"
    local run_cmd="bash cmd.sh" # the command line string
    local MEM_SHOULD_RESERVE=0
    flush_fs_caches

    echo "    => Running [$w - $et - $id], date:$(date) ..."

    if [[ $et == "L100" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 0 -- ""${run_cmd}"
    elif [[ $et == "L0" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 1 -- ""${run_cmd}"
    elif [[ $et == "CXL-Interleave" ]]; then
        run_cmd="numactl --cpunodebind 0 --interleave=all -- ""${run_cmd}"
    elif [[ $et == "Base-Interleave" ]]; then
        # The difference with L50 is that all CPUs on Node 1 are online
        # --cpunodebind 0: this param was errorneously added, need to fix for
        # those multi-threaded workloads!!!! (re-run workloads >600)
        run_cmd="numactl --interleave=all -- ""${run_cmd}"
    else
        # Other base splits (e.g. 90, 80, 70, 60)
        run_cmd="numactl --cpunodebind 0 -- ${run_cmd}"
        #NODE0_TT_MEM=$(sudo numactl --hardware | grep 'node 0 size' | awk '{print $4}')
        NODE0_FREE_MEM=$(sudo numactl --hardware | grep 'node 0 free' | awk '{print $4}')
        ((NODE0_FREE_MEM -= 520))
        # 549 -> 873MB
        APP_MEM_ON_NODE0=$(echo "$mem*$et/100.0" | bc)
        #echo $NODE0_FREE_MEM
        MEM_SHOULD_RESERVE=$((NODE0_FREE_MEM - APP_MEM_ON_NODE0))
        MEM_SHOULD_RESERVE=${MEM_SHOULD_RESERVE%.*}
        #echo $MEM_SHOULD_RESERVE
        #return
    fi

    local output_dir="$RSTDIR/$w/CXL"
    [[ ! -d ${output_dir} ]] && mkdir -p ${output_dir}

    local logf=${output_dir}/${et}-${id}.log
    local timef=${output_dir}/${et}-${id}.time
    local output=${output_dir}/${et}-${id}.output
    local memf=${output_dir}/${et}-${id}.mem
    local pidstatf=${output_dir}/${et}-${id}.pidstat
    local sysinfof=${output_dir}/${et}-${id}.sysinfo
    local emondatf=${output_dir}/${et}-${id}-emon.dat
    local sarf=${output_dir}/${et}-${id}.sar

    {
        echo "===> MemEater reserving [$MEM_SHOULD_RESERVE] MB on Node 0..."
        if [[ $MEM_SHOULD_RESERVE -gt 0 ]]; then
            sudo killall memeater >/dev/null 2>&1
            sleep 10
            # Make sure that MemEater is reserving memory from Node 0
            numactl --cpunodebind 0 --membind 0 -- $MEMEATER ${MEM_SHOULD_RESERVE} &
            mapid=$!
            # Wait until memory eater consume all destined memory
            sleep 120
        fi

        echo "$run_cmd" | tee r.sh
        echo "Start: $(date)"
        get_sysinfo > $sysinfof 2>&1
        /usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} bash r.sh > $output 2>&1 &
        #/usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} sleep 15 > $output 2>&1 &
        cpid=$!
        #pidstat -r -u -d -l -v -p ALL -U -h 5 1000000 > $pidstatf &
        #pstatpid=$!

        if [[ "${RUN_EMON}" == 1 ]]; then
            sudo $EMON -i $RUNDIR/clx-2s-events.txt -f "$emondatf" >/dev/null 2>&1 &
        fi
        #sar -o ${sarf} -bBdHqSwW -I SUM -n DEV -r ALL -u ALL 1 >/dev/null 2>&1 &
        #sarpid=$!
        monitor_resource_util >>$memf 2>&1 &
        mpid=$!

        #disown $pstatpid
        #disown $sarpid
        disown $mpid # avoid the "killed" message
        wait $cpid 2>/dev/null
        if [[ "${RUN_EMON}" == 1 ]]; then
            sudo $EMON -stop
        fi
        #kill -9 $sarpid
        kill -9 $mpid >/dev/null 2>&1
        #kill -9 $pstatpid >/dev/null 2>&1
        if [[ $MEM_SHOULD_RESERVE -gt 0 ]]; then
            disown $mapid
            kill -9 $mapid >/dev/null 2>&1
        fi
        echo "End: $(date)"
        echo "" && echo "" && echo "" && echo ""
        cat r.sh
        echo ""
        cat cmd.sh
        rm -rf r.sh
        sleep 10
    } >> $logf
}

# run "L100" "CXL-Interleave" "L0" in one shot
# $1: "workload"
# $2: id
# $3: Memory (MB)
run_one_workload_cxl()
{
    local w=$1
    local id=$2
    local mem=$3

    run_one_exp "$w" "L100" $id $mem
    run_one_exp "$w" "L0" $id
    # More Splits
    run_one_exp "$w" "95" $id $mem
    run_one_exp "$w" "90" $id $mem
    run_one_exp "$w" "85" $id $mem
    run_one_exp "$w" "80" $id $mem
    run_one_exp "$w" "75" $id $mem
    run_one_exp "$w" "70" $id $mem
    run_one_exp "$w" "60" $id $mem
    run_one_exp "$w" "50" $id $mem
    run_one_exp "$w" "40" $id $mem
    run_one_exp "$w" "30" $id $mem
    run_one_exp "$w" "25" $id $mem
    run_one_exp "$w" "CXL-Interleave" $id
}

# run baseline experiments (e.g. "Base-Interleave"), we put this into a seperate
# function as it does not require any hacks to take cores offline
# $1: "workload"
# $2: id
run_one_workload_base()
{
    local w=$1
    local id=$2

    run_one_exp "$w" "Base-Interleave" $id
}

# Run all 43 SPEC CPU workloads on one server one by one Params:
# $1 -> the experiment type to run.
#
# "L100", "L50", "L0" -> represent the CXL-based exp
# "B50" -> Baseline interleave mode, "L100" <=> "B100"
run_seq_cxl()
{
    check_cxl_conf

    for id in 1 2 3 4 5; do
        for ((i = 0; i < ${#warr[@]}; i++)); do
            w=${warr[$i]}
            m=${marr[$i]}
            cd "$w"
            run_one_workload_cxl "$w" "$id" "$m"
            cd ../
        done
    done
}

run_seq_base()
{
    check_base_conf

    for id in 1 2 3 4 5; do
        for ((i = 0; i < ${#warr[@]}; i++)); do
            w=${warr[$i]}
            cd "$w"
            run_one_workload_base "$w" "$id"
            cd ../
        done
    done
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

main
{
    run_seq_cxl
    run_seq_base
}

main

echo "Congrats! All done!"
exit
