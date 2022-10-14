#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./fotonik3d_r_base.mytest-m64 > fotonik3d_r.log 2>> fotonik3d_r.err
