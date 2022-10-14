#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/urand.sg -i4 -n1
