#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/bc -f ${GAPBS_GRAPH_DIR}/kron.sg -i4 -n4
