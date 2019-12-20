#!/bin/bash
BASEPATH="${PWD}"
echo "Building librustzcash mainnet library..."
cargo build --features=mainnet && cargo lipo --release

mkdir -p lib
cp target/universal/release/* lib/
cp -rf target/universal/release/*  ZcashLightClientKit/zcashlc