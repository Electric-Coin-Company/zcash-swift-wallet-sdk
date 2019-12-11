export PATH="$HOME/.cargo/bin:$PATH"
export RUST_LIB_PATH="${PODS_TARGET_SRCROOT}/lib"
export ZCASH_LIB_RUST_PATH="${PODS_TARGET_SRCROOT}/target"
export ZCASH_LIB_RUST_NAME="libzcashlc.a"
if [ "$ACTION" = "clean" ]; then
    cargo clean
    if [ -d "${RUST_LIB_PATH}" ]; then 
        rm -rf "${RUST_LIB_PATH}"
    fi 
    if [ -d "${ZCASH_LIB_RUST_PATH}" ]; then 
        rm -rf "${ZCASH_LIB_RUST_PATH}"
    fi 
    
else
    cargo lipo --xcode-integ --release --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml

    if [ ! -d "${RUST_LIB_PATH}" ]; then 
        mkdir -p "${RUST_LIB_PATH}"
    fi 
    
    cp -f "${ZCASH_LIB_RUST_PATH}/universal/release/${ZCASH_LIB_RUST_NAME}" ${ZCASH_LIB_RUST_PATH}
fi
