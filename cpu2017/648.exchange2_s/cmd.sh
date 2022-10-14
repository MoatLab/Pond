#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./exchange2_s_base.mytest-m64 6 > exchange2.txt 2>> exchange2.err
