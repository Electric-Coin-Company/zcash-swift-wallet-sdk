#!/bin/sh

SCRIPT_COMMONS="${PODS_TARGET_SRCROOT}/Scripts/script_commons.sh"
if [ ! -f $SCRIPT_COMMONS ]; then
    echo "Failed to load $SCRIPT_COMMONS"
    exit 1
fi
 source $SCRIPT_COMMONS

if [ "$1" = "--testing" ]; then
    export ZCASH_NETWORK_ENVIRONMENT=$ZCASH_TESTNET
    echo "Testing flag detected, forcing $ZCASH_TESTNET"
fi

check_environment

if [ "$ACTION" = "clean" ]; then
    clean
    exit 0
fi

if [ existing_build_mismatch = true ]; then 
    # clean
    echo "build mismatch. You previously build a Different network environment. It appears that your build could be inconsistent if proceeding. Please clean your Pods/ folder and clean your build before running your next build."
    exit 1
fi

if is_mainnet; then
    FEATURE_FLAGS="--features=mainnet"
else 
    FEATURE_FLAGS=""
fi

echo "Building Rust backend"
echo ""
echo "cargo build $FEATURE_FLAGS --release && cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml $FEATURE_FLAGS --release"

if [ ! -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ]; then
    cargo build --release $FEATURE_FLAGS && cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml --release
    persist_environment
fi



if [ ! -d "${RUST_LIB_PATH}" ]; then 
    mkdir -p "${RUST_LIB_PATH}"
fi 

echo "copying artifacts: cp -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"

# ALWAYS SHIP RELEASE NO MATTER WHAT YOUR BUILD IS (FOR NOW AT LEAST)
cp -f "${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME}" "${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
echo "copying artifacts: cp -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
cp -f "${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME}" "${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"

