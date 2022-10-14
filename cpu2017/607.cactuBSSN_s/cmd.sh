#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./cactuBSSN_s_base.mytest-m64 spec_ref.par > spec_ref.out 2>> spec_ref.err
