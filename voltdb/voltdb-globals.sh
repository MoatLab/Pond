#!/bin/bash
# fail fast
#set -euo pipefail

# Global directory for all the voltdb experiment related files
export VDB_TOP_DIR=/tdata/VDB/

export VDB_DB_DIR=${VDB_TOP_DIR}/vdb
export VDB_SRC_DIR=${VDB_TOP_DIR}/voltdb

export VDB_SERVER=10.10.1.22
export VDB_CLIENT=10.10.1.21

export YCSB_DIR="/users/hcli/proj/run/voltdb/ycsb"
