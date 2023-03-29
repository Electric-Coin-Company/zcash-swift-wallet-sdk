#!/bin/zsh

scriptDir=${0:a:h}
cd "${scriptDir}"

source servers_config.zsh
index=0

for syncAlias in $syncAliases; do
    port=$(($startPort+$index))
    rundir="rundir-${syncAlias}"

    mkdir $rundir
    cd $rundir
    lightwalletd --darkside-very-insecure --no-tls-very-insecure --data-dir ./ --grpc-bind-addr "127.0.0.1:${port}" --log-file "stdout.log" --log-level 10 &
    cd ..

    pid="$!"
    echo $pid > "/tmp/lightwalletd-${syncAlias}.pid"

    index=$(($index+1))
done
