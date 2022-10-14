#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./lbm_s_base.mytest-m64 2000 reference.dat 0 0 200_200_260_ldc.of > lbm.out 2>> lbm.err
