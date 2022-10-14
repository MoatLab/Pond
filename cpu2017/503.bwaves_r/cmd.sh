#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./bwaves_r_base.mytest-m64 bwaves_1 < bwaves_1.in > bwaves_1.out 2>> bwaves_1.err
