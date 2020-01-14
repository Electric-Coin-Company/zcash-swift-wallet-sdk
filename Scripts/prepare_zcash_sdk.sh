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


echo "make ${ZCASH_SDK_GENERATED_SOURCES_FOLDER} folder"
mkdir -p ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}

echo "**********************************************"
echo "* create empty ZcashSDK.generated.swift file *"
echo "**********************************************"
echo ""

echo "touch ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}/ZcashSDK.generated.swift"
touch ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}/ZcashSDK.generated.swift

echo "****************************************************************"
echo "* create empty WalletBirthday+saplingtree.generated.swift file *"
echo "****************************************************************"
echo ""

echo "touch $ZCASH_SDK_GENERATED_SOURCES_FOLDER/WalletBirthday+saplingtree.generated.swift"
touch $ZCASH_SDK_GENERATED_SOURCES_FOLDER/WalletBirthday+saplingtree.generated.swift