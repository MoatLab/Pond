#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/bfs -f ${GAPBS_GRAPH_DIR}/kron.sg -n128
