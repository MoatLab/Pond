#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./nab_r_base.mytest-m64 1am0 1122214447 122 > 1am0.out 2>> 1am0.err
