#!/bin/bash

MEMNODE=$1

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > e100.sh
    echo 'curdir=$(pwd)' >> e100.sh
    echo 'w="$(echo ${curdir/\/*run\/})"' >> e100.sh

    echo 'for i in $(seq 1 3); do' >> e100.sh
    echo '    echo "$w start: $(date)" >L100-$i.time' >> e100.sh
    echo '    { time ./r.sh 0; } 2>>L100-$i.time' >> e100.sh
    echo '    echo "$w done: $(date)" >>L100-$i.time' >> e100.sh
    echo 'done' >> e100.sh

    chmod u+x e100.sh
    cd -
done
