#!/bin/bash

source voltdb-globals.sh

VOLTDB_RUN_DIR="/users/hcli/proj/run/voltdb"

cd ${YCSB_DIR}

measure_bw() {
    for accessmode in "zipfian"; do
        for nthreads in 1024; do
            bin/ycsb.sh run voltdb -P workloads/workloada -P \
                ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} \
                -p requestdistribution=${accessmode} -p threadcount=${nthreads} \
                -p fieldlength=10 \
                -p maxexecutiontime=60
            done
    done
}

measure_lat() {
    for tgt in 10 20000 40000 60000 80000 100000 120000; do
    for accessmode in "zipfian"; do
        for nthreads in 256; do
            bin/ycsb.sh run voltdb -P workloads/workloada -P \
                ${VOLTDB_RUN_DIR}/voltdb-run.properties -p voltdb.servers=${VDB_SERVER} \
                -p requestdistribution=${accessmode} -p threadcount=${nthreads} \
                -p fieldlength=10 -p target=$tgt -p maxexecutiontime=60 > $tgt.log
        done
    done
    done
}

#measure_bw
measure_lat
