#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./omnetpp_s_base.mytest-m64 -c General -r 0 > omnetpp.General-0.out 2>> omnetpp.General-0.err
