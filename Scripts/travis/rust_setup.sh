#!/bin/bash

set -x

rustup-init --verbose -y

source $HOME/.cargo/env

rustup target add aarch64-apple-ios x86_64-apple-ios
rustup toolchain add nightly-2021-09-24
rustup +nightly-2021-09-24 target add aarch64-apple-ios-sim x86_64-apple-ios

cargo install cargo-lipo