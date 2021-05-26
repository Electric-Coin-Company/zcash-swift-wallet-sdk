#!/bin/sh

if [[ "$(uname -m)" == "arm64" ]]; then
  export PATH="/opt/homebrew/bin:${PATH}"
fi

SCRIPT_COMMONS="${PODS_TARGET_SRCROOT}/Scripts/script_commons.sh"
if [ -f $SCRIPT_COMMONS ]; then
    source $SCRIPT_COMMONS
else
    echo "Failed to load $SCRIPT_COMMONS"
    exit 1
fi

if ! hash sourcery; then
    echo "Sourcery not found on your PATH"
    exit 1
fi
export ZCASH_SDK_TEMPLATE="${ZCASH_SRC_PATH}/Stencil"

echo "export ZCASH_SRC_PATH=${ZCASH_SRC_PATH}"

check_environment

if is_mainnet; then
    SOURCERY_ARGS="--args dbprefix=ZcashSdk_mainnet_ --args ismainnet=true --args saplingActivationHeight=419_200"
else 
    SOURCERY_ARGS="--args dbprefix=ZcashSdk_testnet_ --args ismainnet=false --args saplingActivationHeight=280_000"
fi

if [ -d $ZCASH_SDK_GENERATED_SOURCES_FOLDER ]; then 
    echo "clean up before generating new files: $ZCASH_SDK_GENERATED_SOURCES_FOLDER"
    echo "rm -rf ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}/*.generated*"
    rm -rf "${ZCASH_SDK_GENERATED_SOURCES_FOLDER}/*.generated*"
else 
    echo "mkdir -p -v $ZCASH_SDK_GENERATED_SOURCES_FOLDER"
    mkdir -p -v ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}
fi

echo "Set +w to ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}"
chmod -R +w ${ZCASH_SDK_GENERATED_SOURCES_FOLDER}

echo "sourcery --prune --verbose --templates ${ZCASH_SDK_TEMPLATE}  --sources ${ZCASH_SRC_PATH} --output ${ZCASH_SDK_GENERATED_SOURCES_FOLDER} $SOURCERY_ARGS "

sourcery --prune --verbose --templates ${ZCASH_SDK_TEMPLATE} --sources ${ZCASH_SRC_PATH} --output ${ZCASH_SDK_GENERATED_SOURCES_FOLDER} $SOURCERY_ARGS

