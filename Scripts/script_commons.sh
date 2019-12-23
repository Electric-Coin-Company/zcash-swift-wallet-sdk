export PATH="$HOME/.cargo/bin:$PATH"
export RUST_LIB_PATH="${PODS_TARGET_SRCROOT}/lib"
export ZCASH_LIB_RUST_BUILD_PATH="${PODS_TARGET_SRCROOT}/target"
export ZCASH_BUILD_TYPE_MAINNET_FLAG=".mainnet_build"
export ZCASH_BUILD_TYPE_TESTNET_FLAG=".testnet_build"
export ZCASH_LIB_RUST_NAME="libzcashlc.a"
export ZCASH_TESTNET="TESTNET"
export ZCASH_MAINNET="MAINNET"

function clean {
    cargo clean
    if [ -d "${RUST_LIB_PATH}" ]; then 
        rm -rf "${RUST_LIB_PATH}"
    fi 
    if [ -d "${ZCASH_LIB_RUST_BUILD_PATH}" ]; then 
        rm -rf "${ZCASH_LIB_RUST_BUILD_PATH}"
    fi 
}

function check_environment {
    if ![ $ZCASH_NETWORK_ENVIRONMENT = $ZCASH_MAINNET ] || ![ $ZCASH_NETWORK_ENVIRONMENT = $ZCASH_TESTNET ]; then
    echo "No network environment set"
    exit 1
    fi
}

function is_mainnet {
    if [ $ZCASH_NETWORK_ENVIRONMENT = $ZCASH_MAINNET ]; then
        true
    else 
        false
    fi
}

function existing_build_mismatch {
    #if build exists check that corresponds to the current network environment
    if [ -d $ZCASH_LIB_RUST_BUILD_PATH ]; then
        if [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_MAINNET_FLAG" ] && [ $ZCASH_NETWORK_ENVIRONMENT = $ZCASH_MAINNET ]; then
            true
        elif [ -f "$ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_TESTNET_FLAG" ] && ![ $ZCASH_NETWORK_ENVIRONMENT != $ZCASH_TESTNET ]; then
            true
        else
            false
        fi
    fi
    false
}

function persist_environment {
    check_environment

    if [ $ZCASH_NETWORK_ENVIRONMENT = "$ZCASH_MAINNET" ]; then 
        touch $ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_MAINNET_FLAG
    elif [ $ZCASH_NETWORK_ENVIRONMENT = "$ZCASH_BUILD_TYPE_TESTNET_FLAG"]; then
        touch $ZCASH_LIB_RUST_BUILD_PATH/$ZCASH_BUILD_TYPE_TESTNET_FLAG
    fi
}