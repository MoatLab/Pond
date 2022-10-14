#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./xalancbmk_s_base.mytest-m64 -v t5.xml xalanc.xsl > ref-t5.out 2>> ref-t5.err
