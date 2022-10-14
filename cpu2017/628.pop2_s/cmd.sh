#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./speed_pop2_base.mytest-m64 > pop2_s.out 2>> pop2_s.err
