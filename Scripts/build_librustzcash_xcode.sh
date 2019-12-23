SCRIPT_COMMONS="${PODS_TARGET_SRCROOT}/Scripts/scripts_common.sh"
if [ -f $SCRIPT_COMMONS ]
    source $SCRIPT_COMMONS
else
    echo "Failed to load script_common.sh"
    exit 1
fi

check_environment

if [ "$ACTION" = "clean" ]; then
    clean
else

    if [ existing_build_mismatch ]; then 
        clean
    fi

    cargo lipo --manifest-path ${PODS_TARGET_SRCROOT}/Cargo.toml
    
    persist_environment
    
    if [ ! -d "${RUST_LIB_PATH}" ]; then 
        mkdir -p "${RUST_LIB_PATH}"
    fi 
    
    cp -f "${ZCASH_LIB_RUST_BUILD_PATH}/universal/${CONFIGURATION}/${ZCASH_LIB_RUST_NAME}" ${ZCASH_LIB_RUST_BUILD_PATH}
fi
