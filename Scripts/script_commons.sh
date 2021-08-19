#!/bin/sh

export PATH="$HOME/.cargo/bin:$PATH"
export RUST_LIB_PATH="${PODS_TARGET_SRCROOT}/lib"
export ZCASH_POD_SCRIPTS="${PODS_TARGET_SRCROOT}/Scripts"
export ZCASH_LIB_RUST_BUILD_PATH="${PODS_TARGET_SRCROOT}/target"

export ZCASH_LIB_RUST_NAME="libzcashlc.a"

export ZCASH_SRC_PATH="${PODS_TARGET_SRCROOT}/ZcashLightClientKit"
export ZCASH_SDK_RUST_LIB_PATH="${ZCASH_SRC_PATH}/zcashlc"


function clean {
    echo "CLEAN DETECTED"
    cargo clean
    if [ -d "${RUST_LIB_PATH}" ]; then 
        rm -rf "${RUST_LIB_PATH}"
    fi 
    if [ -d "${ZCASH_LIB_RUST_BUILD_PATH}" ]; then 
        rm -rf "${ZCASH_LIB_RUST_BUILD_PATH}"
    fi 
}
