#!/bin/bash
#
# Run CXL-memory experiments for GAPBS workloads
#
# Huaicheng Li <lhcwhu@gmail.com>
#

# Change the following global variables based on your environment
#-------------------------------------------------------------------------------
VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"
EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"
VMTOUCH="/usr/bin/vmtouch"
RUNDIR="/users/hcli/proj/run"
DAMON="/users/hcli/git/damo/damo" # user-space tool
TOPLEVDIR=/users/hcli/git/pmu-tools
TOPLEVCMD="sudo PATH=/users/hcli/bin:$PATH $TOPLEVDIR/toplev -l6 -v --no-desc"

# Output folder
#RSTDIR="rst/emon-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
MEMEATER="$RUNDIR/memeater"
GAPBS_RUN_DIR="$RUNDIR/gapbs"
#RSTDIR="${GAPBS_RUN_DIR}/rst/rst"
#RSTDIR="/tdata/gapbs-rst2-full-emon"
#RSTDIR="/tdata/gapbs-rst6-full"
RSTDIR="$RUNDIR/gapbs/rst/asplos22"

echo "==> Result directory: $RSTDIR"

RUN_VTUNE=0
RUN_EMON=0
RUN_DAMON=0
RUN_TOPLEV=0

# GAPBS path, needed by cmd.sh scripts
export GAPBS_DIR="/users/hcli/git/gapbs"
export GAPBS_GRAPH_DIR="/tdata/gapbs/benchmark/graphs"
[[ ! -d "${GAPBS_DIR}" ]] && echo "${GAPBS_DIR} does not exist!" && exit
[[ ! -d "${GAPBS_GRAPH_DIR}" ]] && echo "${GAPBS_GRAPH_DIR} does not exist!" && exit

#-------------------------------------------------------------------------------

# Source global functions
source $RUNDIR/cxl-global.sh || exit
if [[ $RUN_EMON -eq 1 && ! -e $EMON ]]; then
    echo "Error: $EMON not installed"
    echo ""
    exit
fi

if [[ $RUN_DAMON -eq 1 && ! -e $DAMON ]]; then
    echo "Error: $DAMON does not exist"
    echo ""
    exit
fi

if [[ $RUN_TOPLEV -eq 1 && ! -e $TOPLEVDIR/toplev ]]; then
    echo "Error: toplev does not exist"
    echo ""
    exit
fi

TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"

if [[ ! -e /usr/bin/time ]]; then
    echo "Please install GNU time first!"
    exit
fi

if [[ ! -e $VMTOUCH ]]; then
    echo "Please install vmtouch first!"
    exit
fi

# Reserve newlines during command substitution
#IFS=

if [[ $# != 2 ]]; then
    echo ""
    echo "$0 <workload-file> <id>"
    echo "  e.g. $0 w.txt 10 => run the 10th line workload in w.txt"
    echo ""
    exit
fi

wf=$1 # "w.txt"
LID=$2
[[ ! -e $wf ]] && echo "$wf doesnot exist .." && exit

warr=($(cat $wf | head -n $LID | tail -n 1 | grep -v "^#" | awk '{print $1}'))
marr=($(cat $wf | head -n $LID | tail -n 1 | grep -v "^#" | awk '{print $2}'))


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

# Must be called under the corresponding workload folder (e.g. 519.lbm_r/)
# $1: workload
# $2: exp type (L100, L50, L0, "Interleave")
# $3: exp id
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

    echo "    => Running [$w - $et - $id], date:$(date) ..."

    local MEM_SHOULD_RESERVE=0

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
    fi

    local output_dir="$RSTDIR/$w"
    [[ ! -d ${output_dir} ]] && mkdir -p ${output_dir}

    local logf=${output_dir}/${et}-${id}.log
    local timef=${output_dir}/${et}-${id}.time
    local output=${output_dir}/${et}-${id}.output
    local memf=${output_dir}/${et}-${id}.mem
    local pidstatf=${output_dir}/${et}-${id}.pidstat
    local sysinfof=${output_dir}/${et}-${id}.sysinfo
    local emondatf=${output_dir}/${et}-${id}-emon.dat
    local sarf=${output_dir}/${et}-${id}.sar
    local mpstatf=${output_dir}/${et}-${id}.mpstat
    local damonf=${output_dir}/${et}-${id}.damon
    local toplevf=${output_dir}/${et}-${id}.tmam
    local vtune_macc_f=${output_dir}/${et}-${id}-macc
    local vtune_uarch_f=${output_dir}/${et}-${id}-uarch

    {
        if [[ $et != "L100" && $et != "L0" && $et != "Base-Interleave" && $et != "CXL-Interleave" ]]; then
			#NODE0_TT_MEM=$(sudo numactl --hardware | grep 'node 0 size' | awk '{print $4}')
			NODE0_FREE_MEM=$(sudo numactl --hardware | grep 'node 0 free' | awk '{print $4}')
            echo "    ===> Node 0 free: ${NODE0_FREE_MEM}"
			((NODE0_FREE_MEM -= 520))
			# 549 -> 873MB
			APP_MEM_ON_NODE0=$(echo "$mem*$et/100.0" | bc)
			#echo $NODE0_FREE_MEM
			MEM_SHOULD_RESERVE=$((NODE0_FREE_MEM - APP_MEM_ON_NODE0))
			MEM_SHOULD_RESERVE=${MEM_SHOULD_RESERVE%.*}
            echo "    ===> App WSS: ${mem}, Split:$et, Reserving:${MEM_SHOULD_RESERVE}"
			#echo $MEM_SHOULD_RESERVE
			#return
        fi

        echo "        ===> MemEater reserving [$MEM_SHOULD_RESERVE] MB on Node 0..."
        if [[ $MEM_SHOULD_RESERVE -gt 0 ]]; then
            sudo killall memeater >/dev/null 2>&1
            sleep 60
            # Make sure that MemEater is reserving memory from Node 0
            numactl --cpunodebind 0 --membind 0 -- $MEMEATER ${MEM_SHOULD_RESERVE} &
            memeaterpid=$!
            # Wait until memory eater consume all destined memory
            sleep 120
        fi

        echo "$run_cmd" | tee ${w}-r.sh
        echo "Start: $(date)"
        get_sysinfo > $sysinfof 2>&1
        if [[ $RUN_TOPLEV -eq 1 ]]; then
            echo "$run_cmd >/dev/null 2>&1" | tee ${w}-r.sh
            $TOPLEVCMD bash ${w}-r.sh > $toplevf 2>&1 &
            cpid=$!
        else
            /usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} bash ${w}-r.sh > $output 2>&1 &
            cpid=$!
        fi
        #/usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} sleep 15 > $output 2>&1 &
        # this is the real pid of the graph process
        sleep 5
        gpid=$(ps -ef | grep ${GAPBS_GRAPH_DIR} | grep -v grep | grep ${GAPBS_DIR} | awk '{print $2}' | head -n 1)
        echo "cpid=$cpid"
        echo "gpid=$gpid"
        echo ""
        echo $(ps -ef | grep $cpid | grep -v grep)
        echo ""
        echo $(ps -ef | grep $gpid | grep -v grep)

        #pidstat -r -u -d -l -v -p ALL -U -h 5 1000000 > $pidstatf &
        #pstatpid=$!
        #mpstat 1 > ${mpstatf} 2>&1 &
        #mpstatpid=$!
        monitor_resource_util >$memf 2>&1 &
        mpid=$!
        disown $mpid # avoid the "killed" message
        if [[ "${RUN_EMON}" == 1 ]]; then
            sudo numactl --membind 1 $EMON -i $RUNDIR/clx-2s-events.txt -f "$emondatf" >/dev/null 2>&1 &
            sar -o ${sarf} -bBdHqSwW -I SUM -n DEV -r ALL -u ALL 1 >/dev/null 2>&1 &
            sarpid=$!
            disown $sarpid
        fi

        if [[ "${RUN_VTUNE}" == 1 ]]; then
            sudo mkdir -p ${vtune_macc_f}
            sudo $VTUNE -collect memory-access -knob sampling-interval=100 -knob analyze-mem-objects=true -r ${vtune_macc_f} -d 3000 &
            #sudo mkdir -p ${vtune_uarch_f}
            #sudo $VTUNE -collect uarch-exploration -knob sampling-interval=100 -knob collect-memory-bandwidth=false -r ${vtune_uarch_f} -d 3000 &
        fi

        if [[ "${RUN_DAMON}" == 1 ]]; then
            #sudo $DAMON record $gpid -o $damonf
            sudo $DAMON record -s 1000 -a 100000 -u 1000000 -n 1024 -m 1024 -o $damonf $gpid
        fi

        #disown $pstatpid
        #disown $mpstatpid
        wait $cpid 2>/dev/null

        if [[ "${RUN_VTUNE}" == 1 ]]; then
            sudo $VTUNE -r ${vtune_macc_f} -command stop
            #sudo $VTUNE -r ${vtune_uarch_f} -command stop
        fi

        if [[ "${RUN_EMON}" == 1 ]]; then
            sudo $EMON -stop
            kill -9 $sarpid >/dev/null 2>&1
            killall sar >/dev/null 2>&1
            #kill -9 $mpstatpid >/dev/null 2>&1
            #killall mpstat >/dev/null 2>&1 # double kill!
            #kill -9 $pstatpid >/dev/null 2>&1
        fi
        sleep 5
        kill -9 $mpid >/dev/null 2>&1
        if [[ $MEM_SHOULD_RESERVE -gt 0 ]]; then
            disown $memeaterpid
            kill -9 $memeaterpid >/dev/null 2>&1
        fi
        echo "End: $(date)"
        echo "" && echo "" && echo "" && echo ""
        rm -rf ${w}-r.sh
        sleep 10
    } > $logf
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

    killall memeater >/dev/null 2>&1
    sleep 10
    flush_fs_caches

    # Note: put the graph dataset into file cache first for more accurate
    # measurement of memeater, this only needs to be done once for the same
    # workload
    GRAPH_DATASET=$(tail -n 1 cmd.sh | awk '{print $3}' | awk -F'/' '{print $2}')
    echo "    => Graph dataset: ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET}"
    if [[ ! -e "${GAPBS_GRAPH_DIR}/${GRAPH_DATASET}" ]]; then
        echo "    => Error: Input graph ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET} not found .. skipping $w"
        exit
    fi
    echo "    => Loading graph into page cache first"
    numactl --membind 0 ${VMTOUCH} -f -t ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET} -m 64G
    sleep 30

    run_one_exp "$w" "L100" "$id" "$mem"
    run_one_exp "$w" "L0" "$id" "$mem"
    run_one_exp "$w" "CXL-Interleave" "$id" "$mem"

    run_one_exp $w "95" $id $mem
    run_one_exp $w "90" $id $mem
    run_one_exp $w "85" $id $mem
    run_one_exp $w "80" $id $mem
    run_one_exp $w "75" $id $mem
    run_one_exp $w "70" $id $mem
    run_one_exp $w "60" $id $mem
    run_one_exp $w "50" $id $mem
    run_one_exp $w "40" $id $mem
    run_one_exp $w "30" $id $mem
    run_one_exp $w "25" $id $mem

    return
}

# run baseline experiments (e.g. "Base-Interleave"), we put this into a seperate
# function as it does not require any hacks to take cores offline
# $1: workload
# $2: experiment type
# $3: experiment id
run_one_workload_base()
{
    local w=$1
    local id=$2

    echo $w
    run_one_exp "$w" "Base-Interleave" "$id"
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
    echo "run_seq_cxl Done!"
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
    echo "run_seq_base Done!"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------

main()
{
    run_seq_cxl
    run_seq_base
}

main

echo "Congrats! All done!"
exit
