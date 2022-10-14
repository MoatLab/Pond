#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./wrf_s_base.mytest-m64 > rsl.out.0000 2>> wrf.err
