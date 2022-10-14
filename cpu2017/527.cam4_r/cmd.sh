#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./cam4_r_base.mytest-m64 > cam4_r_base.mytest-m64.txt 2>> cam4_r_base.mytest-m64.err
