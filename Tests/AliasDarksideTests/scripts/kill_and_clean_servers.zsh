#!/bin/zsh

scriptDir=${0:a:h}
cd "${scriptDir}"

source servers_config.zsh

for syncAlias in $syncAliases; do
    rundir="rundir-${syncAlias}"
    pidfile="/tmp/lightwalletd-${syncAlias}.pid"
    pid=`cat ${pidfile}`

    kill $pid
    rm -rf $rundir
    rm $pidfile
done
