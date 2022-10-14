#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./sgcc_base.mytest-m64 gcc-pp.c -O5 -fipa-pta -o gcc-pp.opts-O5_-fipa-pta.s > gcc-pp.opts-O5_-fipa-pta.out 2>> gcc-pp.opts-O5_-fipa-pta.err
