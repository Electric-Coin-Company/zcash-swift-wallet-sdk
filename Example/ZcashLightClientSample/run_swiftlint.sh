#!/bin/zsh

PATH="./Example/ZcashLightClientSample/Pods/SwiftLint/:${PATH}:"
cd ../../
if which swiftlint >/dev/null; then
    swiftlint lint --config .swiftlint.yml
else
  echo "error: SwiftLint not installed. Install SwiftLint via cocoapods."
fi

