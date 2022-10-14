#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./x264_s_base.mytest-m64 --pass 1 --stats x264_stats.log --bitrate 1000 --frames 1000 -o BuckBunny_New.264 BuckBunny.yuv 1280x720 > run_000-1000_x264_s_base.mytest-m64_x264_pass1.out 2>> run_000-1000_x264_s_base.mytest-m64_x264_pass1.err
