#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./deepsjeng_s_base.mytest-m64 ref.txt > ref.out 2>> ref.err
