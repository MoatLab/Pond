#!/bin/bash

warr=($(cat w.txt))

#echo ${warr[@]}

# start L0 exp on all the servers in the background
for ((i=0; i < ${#warr[@]}; i++)); do
    w=$(echo ${warr[$i]}| awk -F/ '{print $1}')
    #echo $w
    m=$i
    if [[ $i -ge 15 ]]; then
        ((m++))
    fi
    #ssh -n -f h$i.speccpu2017.memdisagg "sh -c "cd ~/proj/run/$w; nohup { time ./e100.sh ; } >/dev/null 2>&1 &""
    ( ssh h$m.speccpu2017.memdisagg "cd ~/proj/run/$w; ./run-vtune-profiling.sh"; echo "h$m-$w done" ) &
    pid="$pid $!"
done

wait $pid

echo "====> All done!"

exit

ssh -n -f h0.speccpu2017.memdisagg "sh -c 'cd ~/proj/run; nohup { time ./r.sh ; } 2>L0.time >/dev/null 2>&1 &'"
