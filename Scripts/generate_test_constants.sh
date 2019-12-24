#!/bin/sh
#check if env-vars.sh exists
if [ -f ${SRCROOT}/env-vars.sh ]; then
    source ${SRCROOT}/env-vars.sh
fi

export ZCASH_TEST_SRC_PATH="${PODS_TARGET_SRCROOT}/ZcashLightClientKitTests"
if ![ ${LIGHTWALLETD_ADDRESS} ]; then
    echo "LIGHTWALLETD_ADDRESS VARIABLE NOT DEFINED"
    exit 1
fi
echo "export ZCASH_TEST_SRC_PATH=$ZCASH_TEST_SRC_PATH"
#no `else` case needed if the CI works as expecteds
sourcery --templates "${ZCASH_TEST_SRC_PATH}/Stencil"  --sources ${ZCASH_TEST_SRC_PATH} --output ${ZCASH_TEST_SRC_PATH} --args addr=$LIGHTWALLETD_ADDRESS