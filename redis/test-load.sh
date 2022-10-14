#!/bin/bash

source redis-globals.sh

cd ${YCSB_DIR}
bin/ycsb.sh load redis -s -P workloads/workloada -P $REDIS_RUN_DIR/redis-load2.properties -p redis.host=$REDIS_SERVER
