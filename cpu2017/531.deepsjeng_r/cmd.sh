#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./deepsjeng_r_base.mytest-m64 ref.txt > ref.out 2>> ref.err
