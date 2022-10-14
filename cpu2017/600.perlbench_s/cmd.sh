#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./perlbench_s_base.mytest-m64 -I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1 > checkspam.2500.5.25.11.150.1.1.1.1.out 2>> checkspam.2500.5.25.11.150.1.1.1.1.err
