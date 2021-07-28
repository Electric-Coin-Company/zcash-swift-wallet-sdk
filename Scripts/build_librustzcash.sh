#!/bin/bash

BASEPATH="${PWD}"
TARGET_DIR="target"


LIB_PATH="ZcashLightClientKit/$FLAVOR_FOLDER/zcashlc"
echo "++++ Building librustzcash $NETWORK_TYPE library ++++"


if [ -f $TARGET_DIR ]; then
    rm -rf $TARGET_DIR
fi

cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml --release


if [ -f $LIB_PATH ]; then
    rm -rf $LIB_PATH
    mkdir -p $LIB_PATH
fi

cp -rf $TARGET_DIR/universal/release/* $LIB_PATH
