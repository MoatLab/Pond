#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/tc -f ${GAPBS_GRAPH_DIR}/urandU.sg -n3
