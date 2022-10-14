#!/bin/bash
#
# Run EMON profiling for one workload (must run under the workload folder!!)
#
# Huaicheng Li <lhcwhu@gmail.com>
#

RUNDIR="/users/hcli/proj/run"

# Output folder
#RSTDIR="rst/emon-$(date +%F-%H%M)-$(uname -n | awk -F. '{printf("%s.%s\n", $1, $2)}')"
GAPBS_RUN_DIR="${RUNDIR}/gapbs"
#RSTDIR="${GAPBS_RUN_DIR}/rst/emon"
RSTDIR="/tdata/gapbs-emon2-all"

echo "==> Result directory: $RSTDIR"

# Needed by cmd.sh scripts
export GAPBS_DIR="/users/hcli/git/gapbs"
export GAPBS_GRAPH_DIR="/tdata/gapbs/benchmark/graphs"
[[ ! -d "${GAPBS_DIR}" ]] && echo "${GAPBS_DIR} does not exist!" && exit
[[ ! -d "${GAPBS_GRAPH_DIR}" ]] && echo "${GAPBS_GRAPH_DIR} does not exist!" && exit

# Source global functions
source $RUNDIR/cxl-global.sh || exit

# Exp Id (only run once for profiling exp)
id=1

# Array of experiment types
CXL_EXPARR=("L100" "CXL-Interleave" "L0" "95" "90" "85" "80" "75" "50" "25")
BASE_EXPARR=("Base-Interleave")

# Backup purpose
CMDS=(
'${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/twitter.sg -i4 -n16'
'${GAPBS_DIR}/bfs -f ${GAPBS_GRAPH_DIR}/twitter.sg -n64'
'${GAPBS_DIR}/cc -f ${GAPBS_GRAPH_DIR}/twitter.sg -n16'
'${GAPBS_DIR}/pr -f ${GAPBS_GRAPH_DIR}/twitter.sg -i1000 -t1e-4 -n16'
'${GAPBS_DIR}/sssp -f ${GAPBS_GRAPH_DIR}/twitter.wsg -n64 -d2'
'${GAPBS_DIR}/tc -f ${GAPBS_GRAPH_DIR}/twitterU.sg -n3'
)

main()
{
    #---------------------------------------------------------------------------
    # MAIN LOGIC HERE

    WARR=($(cat w.txt | awk '{print $1}'))
    MARR=($(cat one.txt | awk '{print $2}'))

    for ((i = 0; i < ${#WARR[@]}; i++)); do
        w=${WARR[$i]}
        m=${MARR[$i]}
        cd $w
        init_emon_profiling CXL_EXPARR BASE_EXPARR "${RSTDIR}/${w}"

        echo "==> Running $w ..."
        run_emon_all "CXL" CXL_EXPARR "$id" "${RSTDIR}/${w}" ${m}
        run_emon_all "BASE" BASE_EXPARR "$id" "${RSTDIR}/${w}" ${m}

        #cleanup_emon_profiling CXL_EXPARR BASE_EXPARR
        cd ../
    done
    #

    #---------------------------------------------------------------------------
    echo "===> All done (emon profiling)!"
}


main
