#!/bin/bash

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > e.sh
    echo 'curdir=$(pwd)' >> e.sh
    echo 'w="$(echo ${curdir/\/*run\/})"' >> e.sh

    echo 'for i in $(seq 1 3); do' >> e.sh
    echo '    echo "$w start: $(date)" >L100-$i.time' >> e.sh
    echo '    { time ./r.sh; } 2>>L100-$i.time' >> e.sh
    echo '    echo "$w done: $(date)" >>L100-$i.time' >> e.sh
    echo 'done' >> e.sh

    chmod u+x e.sh
    cd -
done
