#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./fotonik3d_s_base.mytest-m64 > fotonik3d_s.log 2>> fotonik3d_s.err
