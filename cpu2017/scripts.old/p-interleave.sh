#!/bin/bash

MEMNODE=$1

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > ei.sh
    echo 'curdir=$(pwd)' >> ei.sh
    echo 'w="$(echo ${curdir/\/*run\/})"' >> ei.sh

    echo 'for i in $(seq 2 2); do' >> ei.sh
    echo '    echo "$w start: $(date)" >Li-$i.time' >> ei.sh
    echo '    { time ./i.sh; } 2>>Li-$i.time' >> ei.sh
    echo '    echo "$w done: $(date)" >>Li-$i.time' >> ei.sh
    echo 'done' >> ei.sh

    chmod u+x ei.sh
    cd -
done
