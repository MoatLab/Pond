#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./mcf_r_base.mytest-m64 inp.in > inp.out 2>> inp.err
