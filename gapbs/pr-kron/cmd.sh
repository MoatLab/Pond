#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/pr -f ${GAPBS_GRAPH_DIR}/kron.sg -i1000 -t1e-4 -n4
