#!/bin/bash

set -x

APP_DIR=${TRAVIS_BUILD_DIR}/Example/ZcashLightClientSample
cd ${APP_DIR}

pod install
