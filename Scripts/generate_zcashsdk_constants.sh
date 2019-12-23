#!/bin/sh

SCRIPT_COMMONS="${PODS_TARGET_SRCROOT}/Scripts/scripts_common.sh"
if [ -f $SCRIPT_COMMONS ]
    source $SCRIPT_COMMONS
else
    echo "Failed to load script_common.sh"
    exit 1
fi

if ![ sourcery --version ]; then
    echo "Sourcery not found on your PATH"
    exit 1
fi

export ZCASH_SRC_PATH="$PODS_TARGET_SRCROOT"
export ZCASH_SDK_TEMPLATE="$ZCASH_SRC_PATH/Stencil/ZcashSDK.stencil"

echo "export ZCASH_SRC_PATH=$ZCASH_SRC_PATH"

check_environment

if [ is_mainnet ]; then
    SOURCERY_ARGS="dbprefix=ZcashSdk_mainnet_ ismainnet=true saplingActivationHeight=419_200"
else 
    SOURCERY_ARGS="dbprefix=ZcashSdk_testnet_ ismainnet=false saplingActivationHeight=280_000"
fi

echo "sourcery --templates ${ZCASH_SDK_TEMPLATE}  --sources ${ZCASH_SRC_PATH} --output ${ZCASH_SRC_PATH} --args $SOURCERY_ARGS"

sourcery --templates ${ZCASH_SDK_TEMPLATE}  --sources ${ZCASH_SRC_PATH} --output ${ZCASH_SRC_PATH} --args $SOURCERY_ARGS