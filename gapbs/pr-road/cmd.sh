#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/pr -f ${GAPBS_GRAPH_DIR}/road.sg -i1000 -t1e-4 -n32
