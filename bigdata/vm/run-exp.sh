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

        for eid in 2 3; do

            echo "===> [$(date)] Running [$grp - $w - $scale]"

            # change hibench.conf
            $SSH_CVM "cd $BDDIR/HiBench; mkdir -p report/asplos22; sed -i \"s/hibench.scale.profile.*/hibench.scale.profile $scale/\" conf/hibench.conf"
            # prepare data first
            $SSH_CVM "$CLEAN_DFS; cd $BDDIR/HiBench; ./bin/workloads/$grp/$w/prepare/prepare.sh; cd $BDDIR/hadoop; ./bin/hdfs dfs -du -h /HiBench > $BDDIR/HiBench/report/asplos22/$grp-$w-$scale-$eid.hdfs"

            # run L100 and collect results
            echo "    ==>  Running L100"
            CONF_L100
            flush_fs_caches
            sleep 5

            echo "======================="
            sudo numactl --hardware
            echo "======================="
            sudo numactl --hardware > $grp-$w-$scale-L100.log
            scp -P8080 $grp-$w-$scale-L100.log huaicheng@localhost:$BDDIR/HiBench/report/asplos22/
            rm -rf $grp-$w-$scale-L100.log
            $SSH_CVM "cd $BDDIR/HiBench; rm -rf report/hibench.report; ./bin/workloads/$grp/$w/spark/run.sh; mv report/hibench.report report/asplos22/$grp-$w-$scale-L100-$eid.report; mv report/$w report/asplos22/$grp-$w-$scale-L100-$eid.logdir"

            sleep 5

            # run L0 and collect results
            echo "    ==>  Running L0"
            CONF_L0
            flush_fs_caches
            sleep 5
            echo "======================="
            sudo numactl --hardware
            echo "======================="
            sudo numactl --hardware > $grp-$w-$scale-L0.log
            scp -P8080 $grp-$w-$scale-L0.log huaicheng@localhost:$BDDIR/HiBench/report/asplos22/
            rm -rf $grp-$w-$scale-L0.log
            $SSH_CVM "cd $BDDIR/HiBench; rm -rf report/hibench.report; ./bin/workloads/$grp/$w/spark/run.sh; mv report/hibench.report report/asplos22/$grp-$w-$scale-L0-$eid.report; mv report/$w report/asplos22/$grp-$w-$scale-L0-$eid.logdir"

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
