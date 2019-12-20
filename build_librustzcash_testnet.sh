#!/bin/bash
BASEPATH="${PWD}"
echo "Building librustzcash testnet library..."
cargo build && cargo lipo --release

mkdir -p lib
cp target/universal/release/* lib/
cp -rf target/universal/release/*  ZcashLightClientKit/zcashlc