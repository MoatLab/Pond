#!/bin/bash

MEMNODE=$1

for i in $(ls -d */); do
    cd $i
    echo "#!/bin/bash" > i.sh
    echo 'echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 && sleep 10' >> i.sh
    cmd=$(specinvoke -n | grep -v "^#" | head -n 1 | sed "s/\.\/.*0000//")
    echo "numactl --interleave=all $cmd" >> i.sh
    chmod u+x i.sh
    cd -
done
