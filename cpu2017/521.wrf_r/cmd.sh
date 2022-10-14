#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./wrf_r_base.mytest-m64 > rsl.out.0000 2>> wrf.err
