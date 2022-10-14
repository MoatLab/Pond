#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./povray_r_base.mytest-m64 SPEC-benchmark-ref.ini > SPEC-benchmark-ref.stdout 2>> SPEC-benchmark-ref.stderr
