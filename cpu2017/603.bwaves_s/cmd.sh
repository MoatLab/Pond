#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./speed_bwaves_base.mytest-m64 bwaves_1 < bwaves_1.in > bwaves_1.out 2>> bwaves_1.err
