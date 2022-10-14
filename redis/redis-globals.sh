#!/bin/bash
# fail fast
#set -euo pipefail

# Global directory for all the voltdb experiment related files
export REDIS_RUN_DIR="/users/hcli/proj/run/redis"
export REDIS_TOP_DIR=/tdata/REDIS/

export REDIS_DB_DIR=${REDIS_TOP_DIR}/rdb

export REDIS_SERVER=10.10.1.20
export REDIS_CLIENT=10.10.1.19

export YCSB_DIR="/users/hcli/proj/run/redis/ycsb"

# Used in redis2.conf for various redis logging
mkdir -p /mnt/redis
