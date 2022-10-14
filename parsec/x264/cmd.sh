#!/bin/bash

./inst/amd64-linux.gcc/bin/x264 --quiet --qp 20 --partitions b8x8,i4x4 --ref 5 --direct auto --weightb --mixed-refs --no-fast-pskip --me umh --subme 7 --analyse b8x8,i4x4 --threads 1 -o eledream.264 ./inputs/eledream_1920x1080_512.y4m
