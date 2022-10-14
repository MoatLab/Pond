#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./imagick_r_base.mytest-m64 -limit disk 0 refrate_input.tga -edge 41 -resample 181% -emboss 31 -colorspace YUV -mean-shift 19x19+15% -resize 30% refrate_output.tga > refrate_convert.out 2>> refrate_convert.err
