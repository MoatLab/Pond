#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=8
export OMP_STACKSIZE=122880
./xz_s_base.mytest-m64 cpu2006docs.tar.xz 6643 055ce243071129412e9dd0b3b69a21654033a9b723d874b2015c774fac1553d9713be561ca86f74e4f16f22e664fc17a79f30caa5ad2c04fbc447549c2810fae 1036078272 1111795472 4 > cpu2006docs.tar-6643-4.out 2>> cpu2006docs.tar-6643-4.err
