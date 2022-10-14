#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./mcf_s_base.mytest-m64 inp.in > inp.out 2>> inp.err
