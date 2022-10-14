#!/bin/bash
#
# Run CXL Spark experiments in a VM
#
# Start the VM first, make sure the HiBench env is correct configured and HDFS
# is already started and working
#
# Host grub: cpu0_hotplug iommu=intel intel_iommu=pt for hotplugging cpu0 and
# NIC dev-passthrough to the VM
#
# VM is started by pre-allocating all the VM memory from Node 0 On the host, we
# dynamically change the online cores on Node 0 and Node 1 to simulate CXL
#
#

EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"
RUNDIR="/users/hcli/proj/run"
BIGDATA_RUN_DIR="${RUNDIR}/bigdata/vm"
RSTDIR="${BIGDATA_RUN_DIR}/rst/emon-asplos22"
echo "==> Result directory: $RSTDIR"

RUN_EMON=1 # 1

if [[ $RUN_EMON == 1 && ! -e $EMON ]]; then
    echo "==> Error: Emon not installed!"
    exit
fi

TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"

if [[ ! -e /usr/bin/time ]]; then
    echo "Please install GNU time first!"
    exit
fi


node0_on() {
    echo 1 | sudo tee /sys/devices/system/node/node0/cpu*/online >/dev/null 2>&1
}

node0_off() {
    echo 0 | sudo tee /sys/devices/system/node/node0/cpu*/online >/dev/null 2>&1
}

node1_on() {
    echo 1 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1
}

node1_off() {
    echo 0 | sudo tee /sys/devices/system/node/node1/cpu*/online >/dev/null 2>&1
}

CONF_L100() {
    node0_on
    node1_off
}

CONF_L0() {
    node1_on
    node0_off
}

source ../../cxl-global.sh

#flush_fs_caches

BDDIR="/home/huaicheng/proj/run/bigdata"
CLEAN_DFS="cd ~/proj/run/bigdata/hadoop; ./bin/hdfs dfs -rm -r /HiBench"


#-------------------------------------------------------------------------------
# CMDs to run in the VM



WG=( $(cat w.txt | awk '{print $1}') )
WL=( $(cat w.txt | awk '{print $2}') )

SSH_CVM="ssh -p8080 huaicheng@localhost"
#CVM="hcli@localhost"

#echo ${WG[@]}
#echo ${WL[@]}

#$SSH_CVM "echo hello"
#exit

# $1: WG
# $2: WL
run_one_exp() {
    grp=$1
    w=$2

    #"huge"
    for scale in "large"; do # "tiny" "small"; do

        for eid in "emon-1"; do #2 3; do
            local output_dir="$RSTDIR/$w/CXL"
            [[ ! -d ${output_dir} ]] && mkdir -p ${output_dir}

            et="L100"
            id=$eid
            local memf=${output_dir}/${et}-${id}.mem
            local emondatf=${output_dir}/${et}-${id}-emon.dat
            local sarf=${output_dir}/${et}-${id}.sar

            echo "===> [$(date)] Running [$grp - $w - $scale]"

            # change hibench.conf
            $SSH_CVM "cd $BDDIR/HiBench; mkdir -p report/emon-asplos22; sed -i \"s/hibench.scale.profile.*/hibench.scale.profile $scale/\" conf/hibench.conf"
            # prepare data first
            $SSH_CVM "$CLEAN_DFS; cd $BDDIR/HiBench; ./bin/workloads/$grp/$w/prepare/prepare.sh; cd $BDDIR/hadoop; ./bin/hdfs dfs -du -h /HiBench > $BDDIR/HiBench/report/emon-asplos22/$grp-$w-$scale-$eid.hdfs"

            # run L100 and collect results
            echo "    ==>  Running L100"
            CONF_L100
            flush_fs_caches
            sleep 5

            echo "======================="
            sudo numactl --hardware
            echo "======================="
            sudo numactl --hardware > ${output_dir}/$grp-$w-$scale-L100.log
            scp -P8080 ${output_dir}/$grp-$w-$scale-L100.log huaicheng@localhost:$BDDIR/HiBench/report/emon-asplos22/
            rm -rf ${output_dir}/$grp-$w-$scale-L100.log
            $SSH_CVM "cd $BDDIR/HiBench; rm -rf report/hibench.report"

            $SSH_CVM "cd $BDDIR/HiBench; ./bin/workloads/$grp/$w/spark/run.sh; mv report/hibench.report report/emon-asplos22/$grp-$w-$scale-L100-$eid.report; mv report/$w report/emon-asplos22/$grp-$w-$scale-L100-$eid.logdir" 2>&1 &
            cpid=$!

            if [[ "${RUN_EMON}" == 1 ]]; then
                sudo $EMON -i $RUNDIR/clx-2s-events.txt -f "$emondatf" >/dev/null 2>&1 &
            fi
            sar -o ${sarf} -bBdHqSwW -I SUM -n DEV -r ALL -u ALL 1 >/dev/null 2>&1 &
            sarpid=$!
            monitor_resource_util >>$memf 2>&1 &
            mpid=$!

            #disown $pstatpid
            disown $sarpid
            disown $mpid # avoid the "killed" message
            wait $cpid 2>/dev/null
            if [[ "${RUN_EMON}" == 1 ]]; then
                sudo $EMON -stop
            fi
            kill -9 $sarpid
            kill -9 $mpid >/dev/null 2>&1

            sleep 5

            $SSH_CVM "cd $BDDIR/HiBench; mv report/hibench.report report/emon-asplos22/$grp-$w-$scale-L100-$eid.report; mv report/$w report/emon-asplos22/$grp-$w-$scale-L100-$eid.logdir"

            # run L0 and collect results
            ###echo "    ==>  Running L0"
            ###CONF_L0
            ###flush_fs_caches
            ###sleep 5
            ###echo "======================="
            ###sudo numactl --hardware
            ###echo "======================="
            ###sudo numactl --hardware > $grp-$w-$scale-L0.log
            ###scp -P8080 $grp-$w-$scale-L0.log huaicheng@localhost:$BDDIR/HiBench/report/asplos22/
            ###rm -rf $grp-$w-$scale-L0.log
            ###$SSH_CVM "cd $BDDIR/HiBench; rm -rf report/hibench.report; ./bin/workloads/$grp/$w/spark/run.sh; mv report/hibench.report report/asplos22/$grp-$w-$scale-L0-$eid.report; mv report/$w report/asplos22/$grp-$w-$scale-L0-$eid.logdir"

        done

    done
}

main() {

    for ((i = 0; i < ${#WL[@]}; i++)); do
        #echo  ${WG[$i]} ${WL[$i]}
        run_one_exp "${WG[$i]}" "${WL[$i]}"
    done
}

main
