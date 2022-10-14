#!/bin/bash

source redis-globals.sh

cd ${YCSB_DIR}

for accessmode in "zipfian"; do
    for nthreads in 1024; do
        bin/ycsb.sh run redis -P workloads/workloada -P \
        ${REDIS_RUN_DIR}/redis-run2.properties -p redis.host=${REDIS_SERVER} \
        -p requestdistribution=${accessmode} -p threadcount=${nthreads} -p \
        measurement.raw.output_file=t.log
    done
done
