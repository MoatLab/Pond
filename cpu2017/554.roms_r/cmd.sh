#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./roms_r_base.mytest-m64 < ocean_benchmark2.in.x > ocean_benchmark2.log 2>> ocean_benchmark2.err
