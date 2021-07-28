# Zcash iOS Framework

[![Build Status](https://travis-ci.org/zcash/ZcashLightClientKit.svg?branch=master)](https://travis-ci.org/zcash/ZcashLightClientKit)


A Zcash Lightweight Client SDK for iOS
This is an alpha build and is currently under active development. Please be advised of the following:

- This code currently is not audited by an external security auditor, use it at your own risk
- The code **has not been subjected to thorough review** by engineers at the Electric Coin Company
- We **are actively changing** the codebase and adding features where/when needed

🔒 Security Warnings

- The Zcash iOS Wallet SDK is experimental and a work in progress. Use it at your own risk.
- Developers using this SDK must familiarize themselves with the current [threat
  model](https://zcash.readthedocs.io/en/latest/rtd_pages/wallet_threat_model.html), especially the known weaknesses described there.

# Build dependencies

ZcashLightClientKit uses a rust library called Librustzcash. In order to build it, you need to have rust and cargo installed on your environment.

Install [Rust](https://www.rust-lang.org/learn/get-started), and then `cargo-lipo`:

```
$ cargo install cargo-lipo
$ rustup target add aarch64-apple-ios x86_64-apple-ios
```

# Cocoapods Support

## Installing as a ZcashLightClientKit as a Contributor
``` ruby
use_frameworks!

pod 'ZcashLightClientKit', :path => '../../', :testspecs => ['Tests']  # include testspecs if you want to run the tests
```

## Installing a wallet app developer
```` ruby
use_frameworks!

pod 'ZcashLightClientKit'
````

### Custom build phases warning
When running `pod install` you will see this warning upon success:
```` bash
[!] ZcashLightClientKit has added 2 script phases. Please inspect before executing a build. 
See `https://guides.cocoapods.org/syntax/podspec.html#script_phases` for more information.
````
Integrating Rust code with Swift code and delivering it in a consistent and (build) reproducible way, is hard. We've taken the lead to get that burden off your shoulders as much as possible by leveraging the `prepare_command` and `script_phases` features from Cocoapods to carefully generate a build for the Rust layer.

## Build system

This section explains the 'Build System' that integrates the rust code and creates the corresponding environment.

### Overview

There are some basic steps to build ZcashLightClientKit. Even though they are 'basic' they can be cumbersome. So we automated them in scripts.

**1. Pod install and `prepare_command`**

ZcashLightClientKit needs files to be present at pod installation time, but that can't be defined properly yet and depend on librustzcash building properly and for an environment to be set up at build time. For know we just need to let Cocoapods that these files exist:

- `${ZCASH_POD_SRCROOT}/zcashlc/libzcashlc.a` this is the librustzcash build .a file itself
- `lib/libzcashlc.a` (as vendored library that will be added as an asset by xcodeproj)


**2. Build Phase**

The build Phase scripts executes within the Xcode Build Step and has all the known variables of a traditional build at hand.

```` ruby
s.script_phase = {
      :name => 'Build generate constants and build librustzcash',
      :script => 'sh ${PODS_TARGET_SRCROOT}/Scripts/build_librustzcash_xcode.sh',
      :execution_position => :before_compile
   }
````

This step will generate files needed on the next steps and build the librustzcash with Xcode but *not using cargo's built-in Xcode integration*

** Building librustzcash and integrating it to the pod structure**

Where the magic happens. Here we will make sure that everything is set up properly to start building librustzcash. When on mainnet, the build will append a parameter to include mainnet features.

### Scripts

On the Scripts folder you will find the following files:
````
 | Scripts
 |-/prepare_zcash_sdk.sh
 |-/generate_test_constants.sh
 |-/build_librustzcash_xcode.sh
 |-/build_librustzcash.sh
 |-/script_commons.sh
 ````

#### prepare_zcash_sdk.sh
This script is run by the Cocoapods 'prepare_command'.

```` Ruby
s.prepare_command = <<-CMD
      sh Scripts/prepare_zcash_sdk.sh
    CMD
````
It basically creates empty files that cocoapods needs to pick up on its pod structure but that are still not present in the file system and that will be generated in later build phases.

NOTE: pod install will only run this phase when no Pods/ folder is present or if your pod hash has changed or is not present on manifest.lock. When in doubt, just clean the Pods/ folder and start over. That usually gets rid of weirdness caused by Xcode caching a lot of stuff you are not aware of.

#### script_commons.sh
A lot of important environment variables and helper functions live in the `script_commons.sh`.


# Testing

Currently tests depend on a `lightwalletd` server instance running locally or remotely to pass.
To know more about running `lightwalletd`, refer to its repo https://github.com/zcash/lightwalletd

## Pointing tests to a lightwalletd instance

Tests use `Sourcery` to generate a Constants file which injects the `lightwalletd` server address to the test themselves.

### Installing sourcery

Refer to the official repo https://github.com/krzysztofzablocki/Sourcery

### Setting env-var.sh file to run locally

Create a file called `env-var.sh` on the project root to create the `LIGHTWALLETD_ADDRESS` environment variable on build time.

```
export LIGHTWALLETD_ADDRESS="localhost%3a9067"
```

### Integrating with CD/CI

The `LIGHTWALLETD_ADDRESS` environment variable can also be added to your shell of choice and `xcodebuild` will pick it up accordingly.

We advise setting this value as a secret variable on your CD/CI environment when possible.

# Integrating with logging tools
There are a lots of good logging tools for iOS. So we'll leave that choice to you. ZcashLightClientKit relies on a simple protocol to bubble up logs to client applications, which is called `Logger` (kudos for the naming originality...)
```
public protocol Logger {
    
    func debug(_ message: String, file: String, function: String, line: Int)
    
    func info(_ message: String, file: String, function: String, line: Int)
    
    func event(_ message: String, file: String, function: String, line: Int)
    
    func warn(_ message: String, file: String, function: String, line: Int)
    
    func error(_ message: String, file: String, function: String, line: Int)
    
}
```
To enable logging you need to do 2 simple steps:
1. have one class conform the `Logger` protocol
2. inject that logger when creating the `Initializer`

For more details look the Sample App's `AppDelegate` code.

# Swiftlint

We don't like reinventing the wheel, so we gently borrowed swift lint rules from AirBnB which we find pretty cool and reasonable.

## Troubleshooting

#### clean pod install
it's not necessary to delete the whole Pods/ directory and download all of your dependencies again
1. on your project root, locate the `Pods/` directory
2. remove ZcashLightClientKit from it
3. clean derived data from Xcode
4. close Xcode
5. run `pod install` (run --verbose to see more details)
6. open Xcode project
7. build

### _function_name  referenced from...
if you get a build error similar to ```_function_name  referenced from...```

* on your project root directory *
1. remove the 'Pods' directory ``` rm -rf Pods/```
2. delete derived data and clean
3. run `pod install`
4. build

### can't find crate for ...  target may not be installed
This error could be a side effect of having more then one rust toolchain installed. 
If you worked with ZcashLightClientKit 0.6.6 or below you might have had to set the compiler to 1.40.0 which can cause this compilation error to happen.
make sure that the directory that you are working on has the correct rust environment.
You can do so by calling `rustup show` in the working directory. 

### Building in Apple Silicon 
So far we have come up with this set up (april 2021)

* Clone a terminal and run it in rosetta mode
* Clone your Xcode of choice and run it in rosetta mode
* Installing the right toolchain for cargo
  * `rustup toolchain add stable-x86_64-apple-darwin`
  * `rustup target add aarch64-apple-ios x86_64-apple-darwin x86_64-apple-ios`
  
## Versioning

This project follows [semantic versioning](https://semver.org/) with pre-release versions. An example of a valid version number is `1.0.4-alpha11` denoting the `11th` iteration of the `alpha` pre-release of version `1.0.4`. Stable releases, such as `1.0.4` will not contain any pre-release identifiers. Pre-releases include the following, in order of stability: `alpha`, `beta`, `rc`. Version codes offer a numeric representation of the build name that always increases. The first six significant digits represent the major, minor and patch number (two digits each) and the last 3 significant digits represent the pre-release identifier. The first digit of the identifier signals the build type. Lastly, each new build has a higher version code than all previous builds. The following table breaks this down:

#### Build Types

| Type  | Purpose | Stability | Audience | Identifier | Example Version |
| :---- | :--------- | :---------- | :-------- | :------- | :--- |
| **alpha** | **Sandbox.** For developers to verify behavior and try features. Things seen here might never go to production. Most bugs here can be ignored.| Unstable: Expect bugs | Internal developers | 0XX | 1.2.3-alpha04 (10203004) |
| **beta** | **Hand-off.** For developers to present finished features. Bugs found here should be reported and immediately addressed, if they relate to recent changes. | Unstable: Report bugs | Internal stakeholders | 2XX | 1.2.3-beta04 (10203204) |
| **release candidate** | **Hardening.** Final testing for an app release that we believe is ready to go live. The focus here is regression testing to ensure that new changes have not introduced instability in areas that were previously working.  | Stable: Hunt for bugs | External testers | 4XX | 1.2.3-rc04 (10203404) |
| **production** | **Delivery.** Deliver new features to end users. Any bugs found here need to be prioritized. Some will require immediate attention but most can be worked into a future release. | Stable: Prioritize bugs | Public | 8XX | 1.2.3 (10203800) |

## Examples

This repo contains demos of isolated functionality that this SDK provides. They can be found in the examples folder.

Examples can be found in the [Demo App](/Example/ZcashLightClientSample).

# License

MIT
