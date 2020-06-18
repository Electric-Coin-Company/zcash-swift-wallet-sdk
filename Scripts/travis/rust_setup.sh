#!/bin/bash

set -x

rustup-init --verbose -y

source $HOME/.cargo/env

cargo install cargo-lipo
rustup target add x86_64-apple-ios
