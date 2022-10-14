#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./nab_s_base.mytest-m64 3j1n 20140317 220 > 3j1n.out 2>> 3j1n.err
