#!/bin/zsh

source servers_config.zsh

for syncAlias in $syncAliases; do
    rundir="rundir-${syncAlias}"
    pidfile="/tmp/lightwalletd-${syncAlias}.pid"
    pid=`cat ${pidfile}`

    kill $pid
    rm -rf $rundir
    rm $pidfile
done
