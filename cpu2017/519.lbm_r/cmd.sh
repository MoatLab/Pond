#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./lbm_r_base.mytest-m64 3000 reference.dat 0 0 100_100_130_ldc.of > lbm.out 2>> lbm.err
