# Zcash iOS Framework
A Zcash Lightweight Client SDK for iOS


# Build dependencies

ZcashLightClientKit uses a rust library called Librustzcash. In order to build it, you need to have rust and cargo installed on your environment. 

Install [Rust](https://www.rust-lang.org/learn/get-started), and then `cargo-lipo`:

```
$ cargo install cargo-lipo
$ rustup target add aarch64-apple-ios x86_64-apple-ios
```

# Cocoapods Support

## Installing as a ZcashLightClientKit as a Contributor
```` ruby
use_frameworks!

pod 'ZcashLightClientKit', :path => '../../', :testspecs => ['Tests']  # include testspecs if you want to run the tests
````

## Installing a wallet app developer
```` ruby
use_frameworks!

pod 'ZcashLightClientKit'
````

### Set Testnet or Mainnet environment
Before building, make sure that your enviroment has the variable `ZCASH_NETWORK_ENVIRONMENT` set to `MAINNET` or `TESTNET`.

### Custom build phases warning 
When running `pod install` you will see this warning upon sucess:
```` bash
[!] ZcashLightClientKit has added 2 script phases. Please inspect before executing a build. 
See `https://guides.cocoapods.org/syntax/podspec.html#script_phases` for more information.
````
Integrating Rust code with Swift code and delivering it in a consistent and (build) reproducible way, is hard. We've taken the lead to get that burden off your shoulders as much as possible by leveraging the `prepare_command` and `script_phases` features from Cocoapods to carefully generate the `TESTNET` and `MAINNET` builds as simple and less error prone as we could think it could be. Which started as some simple vanilla scripts, ended up being some kind of "Build System" on its own. Nothing is written on stone, and we accept collaborations and improvements in this matter too. 

## Build system

This section explains the 'Build System' that integrates the rust code and creates the corresponding environment

### Overview

There are some basic steps to build ZcashLightClientKit. Even though they are 'basic' they can be cumbersome. So we automated them in scripts.

**1. Pod install and `prepare_command`**

ZcashLightClientKit needs files to be present at pod installation time, but that can't be defined properly yet and depend on librustzcash building properly and for an environment to be set up at build time. For know we just need to let Cocoapods that these files exist:

- `${ZCASH_POD_SRCROOT}/zcashlc/libzcashlc.a` this is the librustzcash build .a file itself
- `lib/libzcashlc.a` (as vendored library that will be added as an asset by xcodeproj)
- `ZcashSDK.generated.swift` which contains sensitive values for the SDK that change depending on the network environment we are building for
- `WalletBirthday+saplingtree.generated.swift` helper functions to import existing wallets. 

**2. Build Phase**

The build Phase scripts executes withing the Xcode Build Step and has all the known variables of a traditional build at hand.

```` ruby
s.script_phase = {
      :name => 'Build generate constants and build librustzcash',
      :script => 'sh ${PODS_TARGET_SRCROOT}/Scripts/generate_zcashsdk_constants.sh && sh ${PODS_TARGET_SRCROOT}/Scripts/build_librustzcash_xcode.sh',
      :execution_position => :before_compile
   }
````

This step will generate files needed on the next steps and build the librustzcash with Xcode but *not using cargo's built-in xcode integration*

**a. Generating ZcashSDK constants**

To run this you need `Sourcery`. We use `Stencil` templates to create this files based on the `ZCASH_NETWORK_ENVIRONMENT` value of your choice. You can either integrate sourcery with cocoapods or as part of your environment.

All generated files will be located in the Pods source root within the `Generated` folder. `ZCASH_SDK_GENERATED_SOURCES_FOLDER` represents that path in the build system

**b. Building librust zcash and integrating it to the pod structure.**

Where the magic happens. Here we will make sure that everything is set up properly to start building librustzcash. When on mainnet, the build will append a parameter to include mainnet features. 


**Safeguards points**: 
if it appears that you are about to build something smelly, we will let you know. Combining testnet and mainnet values and artifacts and viceversa leads to unstable builds and may cause lost of funds if ran on production. 
````
if [ existing_build_mismatch = true ]; then 
        # clean
        echo "build mismatch. You previously build a Different network environment. It appears that your build could be inconsistent if proceeding. Please clean your Pods/ folder and clean your build before running your next build."
        exit 1
fi
````
**3. Xcode clean integration**

When performing a clean, we will clean the rust build folders. 

### Scripts

On the Scripts folder you will find the following files:
````
 | Scripts
 |-/prepare_zcash_sdk.sh
 |-/generate_test_constants.sh
 |-/build_librustzcash_xcode.sh
 |-/build_librustzcash.sh
 |-/generate_zcashsdk_constants.sh
 |-/script_commons.sh
 ````

#### prepare_zcash_sdk.sh
This script is run by the Cocoapods 'preapare_command'. 

```` Ruby
s.prepare_command = <<-CMD
      sh Scripts/prepare_zcash_sdk.sh
    CMD
````
It basically creates empty files that cocoapods needs to pick up on it's pod structure but that are still not present in the file system and that will be generated in later build phases. 

NOTE: pod install will only run this phase when no Pods/ folder is present or if your pod hash has changed or is not present on manifest.lock. When in doubt, just clean the Pods/ folder and start over. That usually gets rid of weirdness caused by Xcode caching a lot of stuff you are not aware of. 

#### script_commons.sh
A lot of important environment variables and helper functions live in the `script_commons.sh`. 


# Testing
Currently tests depend on a ```lightwalletd``` server instance runnning locally or remotely to pass.
To know more about running ```lightwalletd```, refer to its repo https://github.com/zcash-hackworks/lightwalletd

## Pointing tests to a lightwalletd instance
Tests use ```Sourcery``` to generate a Constants file which injects the ```lightwalletd``` server address to the test themselves

### Installing sourcery 
refer to the official repo https://github.com/krzysztofzablocki/Sourcery

### Setting env-var.sh file to run locally
create a file called ```env-var.sh``` on the project root to create the ```LIGHTWALLETD_ADDRESS``` environment variable on build time.
```
export LIGHTWALLETD_ADDRESS="localhost%3a9067"
```

### Integrating with CD/CI 
The ```LIGHTWALLETD_ADDRESS``` environment variable can also be added to your shell of choice and ```xcodebuild``` will pick it up accordingly. 


We advice setting this value as a secret variable on your CD/CI environment when possible

# Swiftlint 
We don't like reinveing the wheel, so be gently borrowed swift lint rules from AirBnB which we find pretty cool and reasonable.

## Troubleshooting

#### No network environment....
if you see this message when building:
```No network environment. Set ZCASH_NETWORK_ENVIRONMENT to MAINNET or TESTNET```
make sure your dev environment is has this variable set before the build starts. *DO NOT CHANGE IT DURING THE BUILD PROCESS*. 

#### _function_name  referenced from...
if you get a build error similar to ```_function_name  referenced from...``` 

* on your project root directory *
1. remove the 'Pods' directory ``` rm -rf Pods/```
2. delete derived data and clean
3. run ```pod install```
4. build 


# License 
Apache License Version 2.0
