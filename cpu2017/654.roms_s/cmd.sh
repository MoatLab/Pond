#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./sroms_base.mytest-m64 < ocean_benchmark3.in > ocean_benchmark3.log 2>> ocean_benchmark3.err
