#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./omnetpp_r_base.mytest-m64 -c General -r 0 > omnetpp.General-0.out 2>> omnetpp.General-0.err
