#!/bin/bash
#
# Run CXL-memory experiments for VoltDB/YCSB workloads
# Please run this script from the server node!
#
# Huaicheng Li <lhcwhu@gmail.com>
#
#
#set -u
#set -o pipefail

source voltdb-globals.sh

# Change the following global variables based on your environment
#-------------------------------------------------------------------------------
EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"
RUNDIR="/users/hcli/proj/run"

# Output folder
#RSTDIR="rst/emon-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
MEMEATER="$RUNDIR/memeater"
VOLTDB_RUN_DIR="$RUNDIR/voltdb"
#RSTDIR="${VOLTDB_RUN_DIR}/rst/rst"
RSTDIR="/tdata/VDB/voltdb-toplev-rst"
echo "==> Result directory: $RSTDIR"

TOPLEVDIR=/users/hcli/git/pmu-tools
TOPLEVCMD="sudo PERF=/users/hcli/bin/perf $TOPLEVDIR/toplev --all -v --no-desc -a sleep 60"
DAMON="/users/hcli/git/damo/damo" # user-space tool

RUN_TOPLEV=0
RUN_EMON=0
RUN_DAMON=0

# The path of voltdb source code
export VDB_SRC_DIR="/tdata/VDB/voltdb"
# The database path, only needed for voltdb init
export VDB_DB_DIR="/tdata/VDB/db"

#-------------------------------------------------------------------------------


mkdir -p ${VDB_DB_DIR}
[[ ! -d "${VDB_SRC_DIR}" ]] && echo "${VDB_SRC_DIR} does not exist!" && exit
[[ ! -d "${VDB_DB_DIR}" ]] && echo "${VDB_DB_DIR} does not exist!" && exit
[[ $RUN_TOPLEV -eq 1 && ! -e $TOPLEVDIR/toplev ]] && echo "===> [$TOPDEVDIR/toplev] not found ..." && exit

VDB_SERVER_RUN_CMD="${VDB_SRC_DIR}/bin/voltdb start --dir=${VDB_DB_DIR} --externalinterface=${VDB_SERVER} --http=${VDB_SERVER}:8080 --background"

# Source global functions
source $RUNDIR/cxl-global.sh || exit
[[ $RUN_EMON -eq 1 && ! -e $EMON ]] && echo "Emon ($EMON) doesn't exist..." && exit
[[ $RUN_DAMON -eq 1 && ! -e $DAMON ]] && echo "===> [$DAMON] not found ..." && exit

TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"

if [[ ! -e /usr/bin/time ]]; then
    echo "Please install GNU time first!"
    exit
fi

# Reserve newlines during command substitution
#IFS=

# workloada
warr=(workloada workloadb workloadc workloadd workloade workloadf)
marr=(19344 19344 19344 19344 19344 19344)
#warr=(workloada)
#marr=(19344)

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

start_voltdb_server()
{
    ${VDB_SERVER_RUN_CMD}
    # Make sure it's up
}

stop_voltdb_server()
{
    pid=$(cat /users/hcli/.voltdb_server/server.pid)
    sudo kill $pid >/dev/null 2>&1
    sudo kill -9 $(ps -ef | grep java | grep externalinterface | grep -v grep | awk '{print $2}') >/dev/null 2>&1
}

# Must be called under the corresponding workload folder (e.g. 519.lbm_r/)
# $1: workload
# $2: exp type (L100, L50, L0, "Interleave")
# $3: exp id
# $4: workload wss, required for running more splits (L95 -- L75)
# Require taking all CPUs on Node 1 offline, for VoltDB, make sure the VoltDB
# server is already up before entering this function
run_one_exp()
{
    local w=$1
    local et=$2
    local id=$3
    local mem=$4
    #local run_cmd="$(cat cmd.sh | grep -v "^#")"
    local run_cmd="bash cmd.sh" # the command line string

    local MEM_SHOULD_RESERVE=0

    echo "    => Running [$w - $et - $id], date:$(date) ..."

    # Setup: VoltDB-server <-> VoltDB-client (YCSB) on two different machines
    # The steps for each experiment: [We could load data once for one specific
    # workload, but if ]
    # (1) Start the server
    # (2) Run YCSB from the client node: load data first, then run the real workloads

    if [[ $et == "L100" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 0 -- ""${run_cmd}"
        PREFIX="numactl --cpunodebind 0 --membind 0"
    elif [[ $et == "L0" ]]; then
        run_cmd="numactl --cpunodebind 0 --membind 1 -- ""${run_cmd}"
        PREFIX="numactl --cpunodebind 0 --membind 1"
    elif [[ $et == "CXL-Interleave" ]]; then
        run_cmd="numactl --cpunodebind 0 --interleave=all -- ""${run_cmd}"
        PREFIX="numactl --cpunodebind 0 --interleave=all"
    elif [[ $et == "Base-Interleave" ]]; then
        # The difference with L50 is that all CPUs on Node 1 are online
        # --cpunodebind 0: this param was errorneously added, need to fix for
        # those multi-threaded workloads!!!! (re-run workloads >600)
        run_cmd="numactl --interleave=all -- ""${run_cmd}"
        PREFIX="numactl --interleave=all"
    else
        PREFIX=""
        # Other base splits (e.g. 90, 80, 70, 60)
        run_cmd="numactl --cpunodebind 0 -- ${run_cmd}"
        #NODE0_TT_MEM=$(sudo numactl --hardware | grep 'node 0 size' | awk '{print $4}')
        NODE0_FREE_MEM=$(sudo numactl --hardware | grep 'node 0 free' | awk '{print $4}')
        ((NODE0_FREE_MEM -= 520))
        # 549 -> 873MB
        APP_MEM_ON_NODE1=$(echo "$mem*$et/100.0" | bc)
        #echo $NODE0_FREE_MEM
        MEM_SHOULD_RESERVE=$((NODE0_FREE_MEM - APP_MEM_ON_NODE1))
        MEM_SHOULD_RESERVE=${MEM_SHOULD_RESERVE%.*}
        #echo $MEM_SHOULD_RESERVE
        #return
    fi

    local output_dir="$RSTDIR/$w"
    [[ ! -d ${output_dir} ]] && mkdir -p ${output_dir}

    #  4 16 64 256
    for nthreads in 256; do
        #  "uniform", "zipfian"
        for accessmode in "uniform" "zipfian"; do
            local logf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.log
            local timef=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.time
            local loadoutputf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.loadoutput
            local outputf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.output
            local rawlatf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.rawlat
            local memf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.mem
            local pidstatf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.pidstat
            local sysinfof=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.sysinfo
            #local mpstatf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.mpstat
            local emondatf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.emon
            local sarf=${output_dir}/${et}-${accessmode}-${nthreads}t-${id}.sar
            local damonf=${output_dir}/${et}-${id}.damon
            local toplevf=${output_dir}/${et}-${id}.toplev
            flush_fs_caches

            if [[ ${MEM_SHOULD_RESERVE} -gt 0 ]]; then
                echo "===> MemEater reserving [$MEM_SHOULD_RESERVE] MB on Node 0..."
                killall memeater >/dev/null 2>&1
                sleep 10
                # Make sure that MemEater is reserving memory from Node 0
                sudo numactl --cpunodebind 0 --membind 0 $MEMEATER ${MEM_SHOULD_RESERVE} &
                mapid=$!
                # Wait until memory eater consume all destined memory
                sleep 120
            fi

            echo "$run_cmd" > r.sh
            echo "        => Start [$w - $et - $accessmode - ${nthreads}t - $id]: $(date)"
            get_sysinfo > $sysinfof 2>&1

            # 1. Start VoltDB server first
            stop_voltdb_server >/dev/null 2>&1
            bash r.sh >/dev/null 2>&1 # daemon mode
            sleep 10
            # 2. Then, do the data loading phase from the client, wait until it
            # finishes before moving to the next step
            # /users/hcli/proj/run/voltdb/ycsb
            local R_YCSB_LOAD_CMD="cd /users/hcli/proj/run/voltdb/ycsb; mkdir -p ${output_dir}; $PREFIX -- bin/ycsb.sh load voltdb -s -P workloads/${w} -P ${VOLTDB_RUN_DIR}/voltdb-load.properties -p voltdb.servers=${VDB_SERVER} > ${loadoutputf} 2>&1"
            echo "        => YCSB Loading data ..."
            ssh -T "${VDB_CLIENT}" "${R_YCSB_LOAD_CMD}"
            # 3. Do the YCSB transaction phase

            echo "        => Running [$w - $et - ${accessmode} - ${nthreads}t - $id]"
            #local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/voltdb/ycsb; mkdir -p ${output_dir}; for tgt in 10000 20000 40000 80000 160000; do $PREFIX -- bin/ycsb.sh run voltdb -P workloads/${w} -P ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} -p maxexecutiontime=120 -p target=\$tgt >${outputf}.\$tgt 2>&1; done"
            if [[ "${RUN_DAMON}" == 1 ]]; then
                local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/voltdb/ycsb; mkdir -p ${output_dir}; ($PREFIX -- ./bin/ycsb.sh run voltdb -P workloads/${w} -P ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} >${outputf} 2>&1 &); sleep 1; ycsb_pid=\$(ps -ef | grep java | grep -v grep | awk '{print \$2}'); sudo $DAMON record -s 1000 -a 100000 -u 1000000 -n 1024 -m 1024 -o $damonf \$ycsb_pid >/dev/null 2>&1"
            else
                local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/voltdb/ycsb; mkdir -p ${output_dir}; $PREFIX -- ./bin/ycsb.sh run voltdb -P workloads/${w} -P ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} >${outputf} 2>&1"
                #local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/voltdb/ycsb; mkdir -p ${output_dir}; for tgt in 10000 20000 40000 80000 160000; do $PREFIX -- bin/ycsb.sh run voltdb -P workloads/${w} -P ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} -p maxexecutiontime=120 -p target=\$tgt >${outputf}.\$tgt 2>&1; done"
            fi

            # Put the entire ssh connection in the background
            ssh -T "${VDB_CLIENT}" "${R_YCSB_RUN_CMD}" &
            cpid=$!

            if [[ "${RUN_DAMON}" == 1 ]]; then
                # This is the DAMO monitoring running on the server
                #gpid=$(ps -ef | grep redis-server | grep -v grep | head -n 1 | awk '{print $2}')
                gpid=$(cat /users/hcli/.voltdb_server/server.pid)
                sudo $DAMON record -s 1000 -a 100000 -u 1000000 -n 1024 -m 1024 -o $damonf $gpid >/dev/null 2>&1 &
            fi

            #/usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} bash r.sh >> $output 2>&1 &
            #/usr/bin/time -f "${TIME_FORMAT}" --append -o ${timef} sleep 15 >> $output 2>&1 &
            #cpid=$!

            # Run the workload here (YCSB client workloads: A-F)

            #pidstat -r -u -d -l -v -p ALL -U -h 5 1000000 > $pidstatf &
            #pstatpid=$!
            #mpstat 1 > ${mpstatf} 2>&1 &
            #mpstatpid=$!

            if [[ "${RUN_TOPLEV}" == 1 ]]; then
                ( sleep 10; eval $TOPLEVCMD >$toplevf 2>&1 ) &
            fi

            if [[ "${RUN_EMON}" == 1 ]]; then
                sudo $EMON -i ../clx-2s-events.txt -f "$emondatf" >/dev/null 2>&1 &
                sar -o ${sarf} -bBdHqSwW -I SUM -n DEV -r ALL -u ALL 1 >/dev/null 2>&1 &
                sarpid=$!
                disown $sarpid
            fi
            monitor_resource_util >>$memf 2>&1 &
            mpid=$!
            disown $mpid # avoid the "killed" message

            #disown $pstatpid
            #disown $mpstatpid
            wait $cpid 2>/dev/null

            if [[ "${RUN_DAMON}" == 1 ]]; then
                # Stop DAMO monitoring
                # MUST be the pid for the "sudo ./damo record" script
                damon_pid=$(ps -ef | grep "damo record" | grep sudo | awk '{print $2}')
                sudo kill -SIGINT "${damon_pid}" >/dev/null 2>&1

                # or we can kill the redis-server here ...
            fi

            if [[ "${RUN_EMON}" == 1 ]]; then
                sudo $EMON -stop
                kill -9 $sarpid
            fi
            stop_voltdb_server
            #kill -9 $mpstatpid >/dev/null 2>&1
            killall mpstat >/dev/null 2>&1 # double kill!
            kill -9 $mpid >/dev/null 2>&1
            #kill -9 $pstatpid >/dev/null 2>&1
            if [[ $MEM_SHOULD_RESERVE -gt 0 ]]; then
                disown $mapid
                kill -9 $mapid >/dev/null 2>&1
            fi
            echo "        => End [$w - $et - $accessmode - ${nthreads}t - $id]: $(date)"
            echo ""
            rm -rf r.sh
            sleep 10
        done
    done
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

    # More Splits
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
    run_one_exp "$w" "Base-Interleave" "$id" "1"
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
            #cd "$w"
            run_one_workload_cxl "$w" "$id" "$m"
            #cd ../
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
            #cd "$w"
            run_one_workload_base "$w" "$id"
            #cd ../
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
