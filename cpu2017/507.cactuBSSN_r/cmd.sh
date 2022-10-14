#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./cactusBSSN_r_base.mytest-m64 spec_ref.par > spec_ref.out 2>> spec_ref.err
