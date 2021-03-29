#!/bin/bash

BASEPATH="${PWD}"
TARGET_DIR="target"

FEATURE_FLAGS="--features=mainnet"
NETWORK_TYPE="TESTNET"
FLAVOR_FOLDER="Testnet"


if [ $1 = "--mainnet" ]; then
    FEATURE_FLAGS="--features=mainnet"
    NETWORK_TYPE="MAINNET"
    FLAVOR_FOLDER="Mainnet"
fi

LIB_PATH="ZcashLightClientKit/$FLAVOR_FOLDER/zcashlc"
echo "++++ Building librustzcash $NETWORK_TYPE library ++++"


if [ -f $TARGET_DIR ]; then
    rm -rf $TARGET_DIR
fi

cargo build --release $FEATURE_FLAGS && cargo lipo --release


if [ -f $LIB_PATH ]; then
    rm -rf $LIB_PATH
    mkdir -p $LIB_PATH
fi

cp -rf $TARGET_DIR/universal/release/* $LIB_PATH
