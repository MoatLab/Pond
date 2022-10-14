#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./blender_r_base.mytest-m64 sh3_no_char.blend --render-output sh3_no_char_ --threads 1 -b -F RAWTGA -s 849 -e 849 -a > sh3_no_char.849.spec.out 2>> sh3_no_char.849.spec.err
