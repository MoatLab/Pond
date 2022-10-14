#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/road.sg -i4 -n32
