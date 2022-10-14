#!/bin/bash

MEMNODE=$1

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > e0.sh
    echo 'curdir=$(pwd)' >> e0.sh
    echo 'w="$(echo ${curdir/\/*run\/})"' >> e0.sh

    echo 'for i in $(seq 1 3); do' >> e0.sh
    echo '    echo "$w start: $(date)" >L0-$i.time' >> e0.sh
    echo '    { time ./r.sh 1; } 2>>L0-$i.time' >> e0.sh
    echo '    echo "$w done: $(date)" >>L0-$i.time' >> e0.sh
    echo 'done' >> e0.sh

    chmod u+x e0.sh
    cd -
done
