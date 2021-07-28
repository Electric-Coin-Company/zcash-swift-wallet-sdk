#!/bin/sh

echo "PWD: ${PWD}"

echo "*********************************************"
echo "* create fake .a so pod install picks it up *"
echo "*********************************************"
RUST_LIB_PATH="${PWD}"/lib
mkdir -p -v $RUST_LIB_PATH
echo "******************************************************************************"
echo "   touch $RUST_LIB_PATH/libzcashlc.a   "
echo "******************************************************************************"
touch $RUST_LIB_PATH/libzcashlc.a


ZCASH_POD_ROOT="${PWD}"
ZCASH_POD_SRCROOT="${ZCASH_POD_ROOT}/ZcashLightClientKit"
ZCASH_SDK_GENERATED_SOURCES_FOLDER="${ZCASH_POD_SRCROOT}/Generated"

echo "***************************************************************************"
echo "   touch ${ZCASH_POD_ROOT}/zcashlc/libzcashlc.a" 
echo "***************************************************************************"
touch ${ZCASH_POD_SRCROOT}/zcashlc/libzcashlc.a

echo "***************************************************************************"
echo "   touch ${ZCASH_POD_ROOT}/zcashlc/zcashlc.h" 
echo "***************************************************************************"
touch ${ZCASH_POD_SRCROOT}/zcashlc/zcashlc.h
