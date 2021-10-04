#!/bin/bash

set -x

rustup-init --verbose -y

source $HOME/.cargo/env

rustup toolchain add nightly
rustup +nightly target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
