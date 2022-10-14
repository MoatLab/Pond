#!/bin/bash

# ~/.voltdb_server/server.pid
#voltadmin shutdown
kill -9 $(cat ~/.voltdb_server/server.pid)
kill -9 $(ps -ef | grep voltdb | grep -v grep | awk '{print $2}') >/dev/null 2>&1
