#!/bin/bash
export OMP_NUM_THREADS=8
${GAPBS_DIR}/bfs -f ${GAPBS_GRAPH_DIR}/web.sg -n128
