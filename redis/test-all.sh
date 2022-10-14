#!/bin/bash
# Run from the client node

source redis-globals.sh

# 0: L100, 1: L0
start_redis_server() {
	local memnode=$1
	ssh -T $REDIS_SERVER "cd $REDIS_RUN_DIR; ./stop-redis.sh; sleep 2; numactl --cpunodebind=0 --membind=$memnode ./start-redis.sh; sleep 3"
}


# client: 0->L100, 1->L0
for cmemnode in 0 1; do
	# server: 0->L100, 1->L0
	for smemnode in 0 1; do
		CT="L"
        ST="L"
        [[ $cmemnode == "1" ]] && CT="R"
        [[ $smemnode == "1" ]] && ST="R"
        start_redis_server $smemnode

        # do loading first
        numactl --cpunodebind=0 --membind=$cmemnode bash test-load.sh
		for i in 1 2 3; do
			numactl --cpunodebind=0 --membind=$cmemnode bash test-run.sh > C${CT}S${ST}-$i.log
		done
    done

done
