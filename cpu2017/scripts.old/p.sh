#!/bin/bash

MEMNODE=$1

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > r.sh
    echo 'MEMNODE=$1' >> r.sh
    cmd=$(specinvoke -n | grep -v "^#" | head -n 1 | sed "s/\.\/.*0000//")
    echo "numactl --cpunodebind 0 --membind \$MEMNODE $cmd" >> r.sh
    chmod u+x r.sh
    cd -
done
