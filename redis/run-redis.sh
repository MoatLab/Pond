#!/bin/bash
#
# Run CXL-memory experiments for Redis/YCSB
#
# Huaicheng Li <lhcwhu@gmail.com>
#


# Change the following global variables based on your environment
#-------------------------------------------------------------------------------
RUNDIR="/users/hcli/proj/run"
# Source global functions
source $RUNDIR/run-globals.sh
source $RUNDIR/cxl-global.sh
EXP_RUN_DIR=$RUNDIR/redis
source $EXP_RUN_DIR/redis-globals.sh

# Output folder
#RSTDIR="rst/emon-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
#RSTDIR="${REDIS_RUN_DIR}/rst/rst"
RSTDIR="$REDIS_TOP_DIR/"
echo "==> Result directory: $RSTDIR"

TOPLEVDIR=/users/hcli/git/pmu-tools
TOPLEVCMD="sudo PERF=/users/hcli/bin/perf $TOPLEVDIR/toplev --all -v --no-desc -a sleep 60"

DAMON="/users/hcli/git/damo/damo" # user-space tool

RUN_TOPLEV=1
RUN_DAMON=0
RUN_EMON=0
#-------------------------------------------------------------------------------


[[ $RUN_EMON -eq 1 && ! -e $EMON ]] && echo "===> [$EMON] not found ..." && exit
[[ $RUN_DAMON -eq 1 && ! -e $DAMON ]] && echo "===> [$DAMON] not found ..." && exit
[[ $RUN_TOPLEV -eq 1 && ! -e $TOPLEVDIR/toplev ]] && echo "===> [$TOPDEVDIR/toplev] not found ..." && exit

REDIS_SERVER_RUN_CMD="bash cmd2.sh"

# Reserve newlines during command substitution
#IFS=
# warr -> workloads
# marr -> working set sizes for each workload (profiled offline)
warr=(workloada workloadb workloadc workloadd workloade workloadf)
marr=(19024 19024 19024 19024 19024 19024)

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

stop_redis_server()
{
    #sudo killall redis-server
    sudo /etc/init.d/redis-server stop
    #pid=$(cat ${REDIS_TOP_DIR}/redis-server.pid)
    pid=$(ps -ef  |grep redis-server | grep -v grep | awk '{print $2}')
    for p in $pid; do sudo kill -9 $p >/dev/null 2>&1; done
    killall redis-server >/dev/null 2>&1
    #kill -9 $(ps -ef | grep java | grep externalinterface | grep -v grep | awk '{print $2}') >/dev/null 2>&1
}

# Must be called under the corresponding workload folder (e.g. 519.lbm_r/)
# $1: workload
# $2: exp type (L100, L50, L0, "Interleave")
# $3: exp id
# $4: workload wss, required for running more splits (L95 -- L75)
# Require taking all CPUs on Node 1 offline, for redis, make sure the redis
# server is already up before entering this function
run_one_exp()
{
    local w=$1
    local et=$2
    local id=$3
    local mem=$4
    #local run_cmd="$(cat cmd.sh | grep -v "^#")"
    local run_cmd="bash cmd2.sh" # the command line string

    local MEM_SHOULD_RESERVE=0

    echo "    => Running [$w - $et - $id], date:$(date) ..."

    # Setup: redis-server <-> redis-client (YCSB) on two different machines
    # The steps for each experiment: [We could load data once for one specific
    # workload, but if ]
    # (1) Start the server
    # (2) Run YCSB from the client node: load data first, then run the real workloads

    if [[ $et == "L100" ]]; then
        CPREFIX="numactl --cpunodebind 0 --membind 0"
        run_cmd="numactl --cpunodebind 0 --membind 0 -- ""${run_cmd}"
    elif [[ $et == "L0" ]]; then
        CPREFIX="numactl --cpunodebind 0 --membind 1"
        run_cmd="numactl --cpunodebind 0 --membind 1 -- ""${run_cmd}"
    elif [[ $et == "CXL-Interleave" ]]; then
        CPREFIX="numactl --cpunodebind 0 --interleave=all"
        run_cmd="numactl --cpunodebind 0 --interleave=all -- ""${run_cmd}"
    elif [[ $et == "Base-Interleave" ]]; then
        # The difference with L50 is that all CPUs on Node 1 are online
        # --cpunodebind 0: this param was errorneously added, need to fix for
        # those multi-threaded workloads!!!! (re-run workloads >600)
        CPREFIX="numactl --interleave=all"
        run_cmd="numactl --interleave=all -- ""${run_cmd}"
    else
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

    for nthreads in 1024; do
        #  "uniform", "zipfian"
        for accessmode in "uniform" "zipfian"; do
            local RUN_F_PREFIX="${output_dir}/${et}-${accessmode}-${nthreads}t-${id}"
            local logf=${RUN_F_PREFIX}.log
            local timef=${RUN_F_PREFIX}.time
            local loadoutputf=${RUN_F_PREFIX}.loadoutput
            local outputf=${RUN_F_PREFIX}.output
            local rawlatf=${RUN_F_PREFIX}.rawlat
            local memf=${RUN_F_PREFIX}.mem
            local pidstatf=${RUN_F_PREFIX}.pidstat
            local sysinfof=${RUN_F_PREFIX}.sysinfo
            local emondatf=${RUN_F_PREFIX}.emon
            #local mpstatf=${RUN_F_PREFIX}.mpstat
            local damonf=${output_dir}/${et}-${id}.damon
            local sarf=${RUN_F_PREFIX}.sar
            local toplevf=${RUN_F_PREFIX}.toplev
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

            # 1. Start redis server first
            stop_redis_server >/dev/null 2>&1
            bash r.sh >/dev/null 2>&1 # daemon mode
            sleep 10
            # 2. Then, do the data loading phase from the client, wait until it
            # finishes before moving to the next step
            # /users/hcli/proj/run/redis/ycsb
            local R_YCSB_LOAD_CMD="cd /users/hcli/proj/run/redis/ycsb; mkdir -p ${output_dir}; $CPREFIX -- ./bin/ycsb load redis -s -P workloads/${w} -P ${REDIS_RUN_DIR}/redis-load2.properties > ${loadoutputf} 2>&1"
            echo "        => YCSB Loading data ..."
            ssh -T "${REDIS_CLIENT}" "${R_YCSB_LOAD_CMD}"


            # 3. Do the YCSB transaction phase
            echo "        => Running [$w - $et - ${accessmode} - ${nthreads}t - $id]"

            if [[ "${RUN_DAMON}" == 1 ]]; then
                local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/redis/ycsb; mkdir -p ${output_dir}; ($CPREFIX -- ./bin/ycsb run redis -P workloads/${w} -P ${REDIS_RUN_DIR}/redis-run2.properties -p redis.host=${REDIS_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} >${outputf} 2>&1 &); sleep 1; ycsb_pid=\$(ps -ef | grep java | grep -v grep | awk '{print \$2}'); sudo $DAMON record -s 1000 -a 100000 -u 1000000 -n 1024 -m 1024 -o $damonf \$ycsb_pid >/dev/null 2>&1"
            else
                local R_YCSB_RUN_CMD="cd /users/hcli/proj/run/redis/ycsb; mkdir -p ${output_dir}; $CPREFIX -- ./bin/ycsb run redis -P workloads/${w} -P ${REDIS_RUN_DIR}/redis-run2.properties -p redis.host=${REDIS_SERVER} -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p measurement.raw.output_file=${rawlatf} >${outputf} 2>&1"
            fi
            # Put the entire ssh connection in the background
            ssh -T "${REDIS_CLIENT}" "${R_YCSB_RUN_CMD}" &
            cpid=$!

            if [[ "${RUN_DAMON}" == 1 ]]; then
                # This is the DAMO monitoring running on the server
                gpid=$(ps -ef | grep redis-server | grep -v grep | head -n 1 | awk '{print $2}')
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
                (sleep 10; eval $TOPLEVCMD > $toplevf 2>&1) &
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
            stop_redis_server
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
    run_one_exp $w "65" $id $mem
    run_one_exp $w "60" $id $mem
    run_one_exp $w "50" $id $mem
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

    for id in 1; do
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

    for id in 1; do
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
