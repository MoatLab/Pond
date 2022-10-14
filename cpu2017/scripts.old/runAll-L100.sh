#!/bin/bash

warr=($(ls -d */))

#echo ${warr[@]}

# start L100 exp on all the servers in the background
for ((i=0; i < ${#warr[@]}; i++)); do
    w=$(echo ${warr[$i]}| awk -F/ '{print $1}')
    #echo $w
    #ssh -n -f h$i.speccpu2017.memdisagg "sh -c "cd ~/proj/run/$w; nohup { time ./e100.sh ; } >/dev/null 2>&1 &""
    ( ssh h$i.speccpu2017.memdisagg "cd ~/proj/run/$w; ./e100.sh"; echo "h$i done" ) &
    pid="$pid $!"
done

wait $pid

exit

ssh -n -f h0.speccpu2017.memdisagg "sh -c 'cd ~/proj/run; nohup { time ./r.sh ; } 2>L100.time >/dev/null 2>&1 &'"
