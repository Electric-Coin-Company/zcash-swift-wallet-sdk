#!/bin/sh

export PATH="$HOME/.cargo/bin:$PATH"
export RUST_LIB_PATH="${PODS_TARGET_SRCROOT}/lib"
export ZCASH_POD_SCRIPTS="${PODS_TARGET_SRCROOT}/Scripts"
export ZCASH_LIB_RUST_BUILD_PATH="${PODS_TARGET_SRCROOT}/target"
export ZCASH_BUILD_TYPE_MAINNET_FLAG=".mainnet_build"
export ZCASH_BUILD_TYPE_TESTNET_FLAG=".testnet_build"
export ZCASH_LIB_RUST_NAME="libzcashlc.a"
export ZCASH_TESTNET="TESTNET"
export ZCASH_MAINNET="MAINNET"
export ZCASH_SRC_PATH="${PODS_TARGET_SRCROOT}/ZcashLightClientKit"
export ZCASH_SDK_RUST_LIB_PATH="${ZCASH_SRC_PATH}/zcashlc"
export ZCASH_SDK_GENERATED_SOURCES_FOLDER="${ZCASH_SRC_PATH}/Generated"

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

function check_environment {

    if [[ $ZCASH_NETWORK_ENVIRONMENT != $ZCASH_MAINNET ]] && [[ $ZCASH_NETWORK_ENVIRONMENT != $ZCASH_TESTNET ]]; then
        echo "No network environment. Set ZCASH_NETWORK_ENVIRONMENT to $ZCASH_MAINNET or $ZCASH_TESTNET"
        exit 1
    fi

    if [[ ! $ZCASH_SDK_GENERATED_SOURCES_FOLDER ]]; then
        echo "No 'ZCASH_SDK_GENERATED_SOURCES_FOLDER' variable present. Delete Pods/ and run 'pod install --verbose'"
        exit 1
    fi

    echo "**** Building for $ZCASH_NETWORK_ENVIRONMENT environment ****"
}

function is_mainnet {
    if [[ $ZCASH_NETWORK_ENVIRONMENT = $ZCASH_MAINNET ]]; then
        true    
    else 
        false
    fi
}
# Return success (0) if there is a build mismatch, else failure (1) if no mismatch.
function existing_build_mismatch {
    #if build exists check that corresponds to the current network environment
    if [! -d $ZCASH_LIB_RUST_BUILD_PATH ]; then
        return 1
    fi

    # there's a MAINNET Flag and MAINNET ENVIRONMENT
    if [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_MAINNET_FLAG" ] && [[ "$ZCASH_NETWORK_ENVIRONMENT" = "$ZCASH_MAINNET" ]]
    then
        return 1 # no build mismatch
    fi

    if [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_MAINNET_FLAG" ] && [[ "$ZCASH_NETWORK_ENVIRONMENT" = "$ZCASH_TESTNET" ]]
    then 
        warn_mismatch $ZCASH_MAINNET $ZCASH_NETWORK_ENVIRONMENT
        return 0 # build mismatch in place
    fi

    # There's a TESTNET flag and we are on TESTNET ENVIRONMENT    
    if [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_TESTNET_FLAG" ] && [[ "$ZCASH_NETWORK_ENVIRONMENT" = "$ZCASH_TESTNET" ]]
    then
        return 1 # no build mismatch 
    fi
    # There's a TESTNET flag and we are on a MAINNET Environment 
    if [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_TESTNET_FLAG" ] && [[ "$ZCASH_NETWORK_ENVIRONMENT" = "$ZCASH_MAINNET" ]]
    then
        warn_mismatch $ZCASH_TESTNET $ZCASH_NETWORK_ENVIRONMENT
        return 0 # build mismatch in place 
    fi
    echo "=== NO BUILD FLAG, CHECKING ENVIRONMENT ==="
    check_environment
    return 1 # no build mismatch    
}

function warn_mismatch {
    echo "*** WARNING: *** build mismatch. Found ${0} but environment is ${1}"
}

function persist_environment {
    check_environment

    if [ $ZCASH_NETWORK_ENVIRONMENT = "$ZCASH_MAINNET" ]
    then 
        touch $ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_MAINNET_FLAG
    elif [[ "$ZCASH_NETWORK_ENVIRONMENT" = "$ZCASH_TESTNET" ]]
    then
        touch $ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_TESTNET_FLAG
    fi
}
