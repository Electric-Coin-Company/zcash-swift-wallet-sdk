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
    echo "CLEAN DETECTED"
    clean
    exit 0
fi

if [ existing_build_mismatch = true ]; then 
    # clean
    echo "Build mismatch. You previously built a different network environment. It appears that your build could be inconsistent if proceeding. Please clean your Pods/ folder and clean your build before running your next build."
    exit 1
fi

if is_mainnet; then
    FEATURE_FLAGS="--features=mainnet"
else 
    FEATURE_FLAGS=""
fi

echo "Building Rust backend"
echo ""
echo "platform name"
echo $PLATFORM_NAME
if [ $PLATFORM_NAME = "iphonesimulator" ]; then
    ZCASH_ACTIVE_ARCHITECTURE="x86_64-apple-ios"
else 
    ZCASH_ACTIVE_ARCHITECTURE="aarch64-apple-ios"
fi

echo "cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml $FEATURE_FLAGS --targets $ZCASH_ACTIVE_ARCHITECTURE --release"
if [[ -n "${DEVELOPER_SDK_DIR:-}" ]]; then
  # Assume we're in Xcode, which means we're probably cross-compiling.
  # In this case, we need to add an extra library search path for build scripts and proc-macros,
  # which run on the host instead of the target.
  # (macOS Big Sur does not have linkable libraries in /usr/lib/.)
  echo "export LIBRARY_PATH=\"${DEVELOPER_SDK_DIR}/MacOSX.sdk/usr/lib:${LIBRARY_PATH:-}\""
  export LIBRARY_PATH="${DEVELOPER_SDK_DIR}/MacOSX.sdk/usr/lib:${LIBRARY_PATH:-}"
fi
if [ ! -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ]; then
    cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml $FEATURE_FLAGS --targets $ZCASH_ACTIVE_ARCHITECTURE --release
    persist_environment
fi



if [ ! -d "${RUST_LIB_PATH}" ]; then 
    mkdir -p "${RUST_LIB_PATH}"
fi 

echo "clean up existing artifacts: rm -f ${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
rm -f "${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
echo "clean up sdk lib path: rm -f ${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
rm -f "${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
echo "copying artifacts: cp -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"

# ALWAYS SHIP RELEASE NO MATTER WHAT YOUR BUILD IS (FOR NOW AT LEAST)
cp -f "${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME}" "${ZCASH_SDK_RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
echo "copying artifacts: cp -f ${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME} ${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"
cp -f "${ZCASH_LIB_RUST_BUILD_PATH}/universal/release/${ZCASH_LIB_RUST_NAME}" "${RUST_LIB_PATH}/${ZCASH_LIB_RUST_NAME}"

