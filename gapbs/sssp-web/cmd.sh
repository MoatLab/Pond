#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/sssp -f ${GAPBS_GRAPH_DIR}/web.wsg -n64 -d2
