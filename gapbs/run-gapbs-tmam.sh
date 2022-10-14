#!/bin/bash
# Run TMAM analysis for L100 and potentiall L0, L50 in future

TOPLEVDIR=/users/hcli/git/pmu-tools
TOPLEVRSTDIR=$(pwd)/rst/toplev

# Needed by cmd.sh scripts
export GAPBS_DIR="/users/hcli/git/gapbs"
export GAPBS_GRAPH_DIR="/tdata/gapbs/benchmark/graphs"
[[ ! -d "${GAPBS_DIR}" ]] && echo "${GAPBS_DIR} does not exist!" && exit
[[ ! -d "${GAPBS_GRAPH_DIR}" ]] && echo "${GAPBS_GRAPH_DIR} does not exist!" && exit

#exit
mkdir -p $TOPLEVRSTDIR

usage() {
    echo ""
    echo "$0 [all | 1-30]"
    echo "  e.g., $0 all"
    echo "  e.g., $0 20"
    echo ""
}

if [[ $# != 1 ]]; then
    usage
    exit
fi

if [[ $1 == "all" ]]; then
    W=( $(cat w.txt | awk '{print $1}') )
elif [[ $1 -ge 1 && $1 -le 30 ]]; then
    W=( $(awk -vline=$1 'NR==line {print $1}' w.txt) )
else
    usage
    exit
fi

#echo ${W[@]}
#exit

echo $TOPLEVRSTDIR
source ../cxl-global.sh
check_cxl_conf

# toplev command line prefix
TOPLEVCMD="sudo $TOPLEVDIR/toplev -l6 -v --no-desc"

# sudo ~/git/pmu-tools/toplev -l6 -v --no-desc

for ((wi = 0; wi < ${#W[@]}; wi++)); do
    w=${W[$wi]}
    cd $w
    echo "===> Running $w w/ Toplev (TMAM) at [$(date)]"
    PROG=$(cat cmd.sh | tail -n 1 | awk '{print $1}' | awk -F/ '{print $2}')


    for s in "L100" "L0"; do
        echo "  => Running $s [$w]"
        killall $PROG 2>/dev/null
        flush_fs_caches

        # Note: put the graph dataset into file cache first for more accurate
        # measurement of memeater, this only needs to be done once for the same
        # workload
        GRAPH_DATASET=$(tail -n 1 cmd.sh | awk '{print $3}' | awk -F'/' '{print $2}')
        echo "    => Graph dataset: ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET}"
        if [[ ! -e "${GAPBS_GRAPH_DIR}/${GRAPH_DATASET}" ]]; then
            echo "    => Error: Input graph ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET} not found .. skipping $w"
            exit
        fi
        echo "    => Loading graph into page cache first"
        numactl --membind 0 vmtouch -f -t ${GAPBS_GRAPH_DIR}/${GRAPH_DATASET} -m 64G
        sleep 30

        if [[ $s == "L100" ]]; then
            WCMD="numactl --cpunodebind 0 --membind 0 -- ./cmd.sh"
        elif [[ $s == "L0" ]]; then
            WCMD="numactl --cpunodebind 0 --membind 1 -- ./cmd.sh"
        else
            echo "Bummer, only supporting L100 and L0 TMAM run now"
            exit
        fi

        $TOPLEVCMD $WCMD > $TOPLEVRSTDIR/$w-$s.tmam 2>&1
    done

    cd ../
    killall $PROG 2>/dev/null
done
