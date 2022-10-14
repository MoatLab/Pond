#!/bin/bash

for w in $(cat wi5.txt); do
    #rm -rf $w/rst/rst-moreSplit-L100-2021-02-26-1224-node0.thoth
    #continue
    cd $w/rst/rst-moreSplit-L50-2021-02-26-1432-node0.thoth
    echo "$w"
    for i in 50; do
        cat $i-1.time | grep Real
    done | awk '{print $2}'
    echo ""
    echo ""
    cd -
done

exit

for w in $(cat wi5.txt); do
    cd $w/rst/rst-moreSplit-2021-02-26-0420-node0.thoth
    echo "$w"
    for i in 95 90 85 80 75; do
        cat $i-1.time | grep Real
    done | awk '{print $2}'
    echo ""
    echo ""
    cd -
done
