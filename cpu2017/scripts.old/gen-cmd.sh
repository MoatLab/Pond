#!/bin/bash

MEMNODE=$1

#
cd ~/cpuspec
. shrc
cd - >/dev/null 2>&1

# 5xx: 1 thread
# 6xx: 8 threads
# $1: Number of threads to use
gen_cmd()
{
    NT=$1

    cd $w
    echo "===> Working on $w ..."
    echo "#!/bin/bash" > cmd.sh
    echo "ulimit -s unlimited" >> cmd.sh
    echo "export OMP_NUM_THREADS=$NT" >> cmd.sh
    echo "export OMP_STACKSIZE=122880" >> cmd.sh

    scmd=$(specinvoke -n | grep -v "^#" | head -n 1)
    if [[ $(echo $scmd | grep refrate) ]]; then
        cmd=$(echo $scmd | sed "s/\.\/run_base_refrate_mytest-m64\.0000//")
    elif [[ $(echo $scmd | grep refspeed) ]]; then
        cmd=$(echo $scmd | sed "s/\.\/run_base_refspeed_mytest-m64\.0000//")
    fi

    #echo $cmd
    echo "$cmd" >> cmd.sh
    chmod u+x cmd.sh
    cd ../
}

for w in $(cat w.txt); do
    if [[ $w =~ ^5.* ]]; then
        gen_cmd 1
    else
        gen_cmd 8
    fi
done

# 6xx: 8 threads
