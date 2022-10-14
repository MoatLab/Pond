#!/bin/bash

#sudo killall redis-server
sudo /etc/init.d/redis-server stop
#pid=$(cat ${REDIS_DIR}/redis-server.pid)
pid=$(ps -ef  |grep redis-server | grep -v grep | awk '{print $2}')
sudo kill -9 $pid >/dev/null 2>&1
#kill -9 $(ps -ef | grep java | grep externalinterface | grep -v grep | awk '{print $2}') >/dev/null 2>&1
