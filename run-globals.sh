#!/bin/bash

TOPDIR="/users/hcli/proj/run"

export VTUNE="/opt/intel/oneapi/vtune/2021.1.2/bin64/vtune"
export EMON="/opt/intel/oneapi/vtune/2021.1.2/bin64/emon"
export EMON_EVENT_FILE="$TOPDIR/clx-2s-events.txt"
export DAMON="/users/hcli/git/damo/damo" # user-space tool

RUNDIR="${TOPDIR}"

MEMEATER="$RUNDIR/memeater"

TIME_FORMAT="\n\n\nReal: %e %E\nUser: %U\nSys: %S\nCmdline: %C\nAvg-total-Mem-kb: %K\nMax-RSS-kb: %M\nSys-pgsize-kb: %Z\nNr-voluntary-context-switches: %w\nCmd-exit-status: %x"
[[ ! -e /usr/bin/time ]] && echo "===> Please install GNU time first!" && exit
