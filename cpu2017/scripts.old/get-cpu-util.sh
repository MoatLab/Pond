#!/bin/bash

for i in $(ls -d */); do
    i=${i%/}
    cd $i
    exe=$(cat r.sh | tail -n 1 | awk '{print $6}')
    w=$(basename $i)
    k=${w##*.}
    printf "%32s %16.0f\n" $i $(grep $exe pidstat.log | grep -v bash  | awk '{print $9}' | sort -n | tail -n 1)
    cd ../
done
