#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./exchange2_r_base.mytest-m64 6 > exchange2.txt 2>> exchange2.err
