#!/bin/bash

VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"

# 1, -app-working-dir /users/hcli/proj/n
# performance-snapshot


for w in $(ls -d */); do
    cd $w

    #for i in 0 1; do
    # node 0 (100%)
    #sudo $VTUNE -collect memory-access -knob sampling-interval=100 -knob analyze-mem-objects=true -- ../r.sh 0
    #sleep 10
    #sudo $VTUNE -collect uarch-exploration -knob sampling-interval=100 -knob collect-memory-bandwidth=true -- ../r.sh 0
    #sleep 10
    sudo $VTUNE -collect memory-consumption -- ./r.sh 0
    #sleep 10


    cd ../
    #done
done

