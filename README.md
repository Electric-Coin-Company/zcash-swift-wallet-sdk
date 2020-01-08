# Zcash iOS Framework

A Zcash Lightweight Client SDK for iOS

This is an alpha build and is currently under active development. Please be advised of the following:

- This code currently is not audited by an external security auditor, use it at your own risk
- The code **has not been subjected to thorough review** by engineers at the Electric Coin Company
- We **are actively changing** the codebase and adding features where/when needed

🔒 Security Warnings

The Zcash iOS Wallet SDK is experimental and a work in progress. Use it at your own risk.

# Build dependencies

Install [Rust](https://www.rust-lang.org/learn/get-started), and then `cargo-lipo`:

```
$ cargo install cargo-lipo
$ rustup target add aarch64-apple-ios x86_64-apple-ios
```

# Cocoapods Support

```ruby
use_frameworks!

pod 'ZcashLightClientKit'
```

# Testing

Currently tests depend on a `lightwalletd` server instance runnning locally or remotely to pass.
To know more about running `lightwalletd`, refer to its repo https://github.com/zcash-hackworks/lightwalletd

## Pointing tests to a lightwalletd instance

Tests use `Sourcery` to generate a Constants file which injects the `lightwalletd` server address to the test themselves

### Installing sourcery

refer to the official repo https://github.com/krzysztofzablocki/Sourcery

### Setting env-var.sh file to run locally

create a file called `env-var.sh` on the project root to create the `LIGHTWALLETD_ADDRESS` environment variable on build time.

```
export LIGHTWALLETD_ADDRESS="localhost%3a9067"
```

### Integrating with CD/CI

The `LIGHTWALLETD_ADDRESS` environment variable can also be added to your shell of choice and `xcodebuild` will pick it up accordingly.

We advice setting this value as a secret variable on your CD/CI environment when possible

# Swiftlint

We don't like reinveing the wheel, so be gently borrowed swift lint rules from AirBnB which we find pretty cool and reasonable.

## Troubleshooting

#### \_function_name referenced from...

if you get a build error similar to `_function_name referenced from...`

- on your project root directory \*

1. remove the 'Pods' directory `rm -rf Pods/`
2. delete derived data and clean
3. run `pod install`
4. build

## Versioning

This project follows [semantic versioning](https://semver.org/) with pre-release versions. An example of a valid version number is `1.0.4-alpha11` denoting the `11th` iteration of the `alpha` pre-release of version `1.0.4`. Stable releases, such as `1.0.4` will not contain any pre-release identifiers. Pre-releases include the following, in order of stability: `alpha`, `beta`, `rc`. Version codes offer a numeric representation of the build name that always increases. The first six significant digits represent the major, minor and patch number (two digits each) and the last 3 significant digits represent the pre-release identifier. The first digit of the identifier signals the build type. Lastly, each new build has a higher version code than all previous builds. The following table breaks this down:

#### Build Types

| Type  | Purpose | Stability | Audience | Identifier | Example Version |
| :---- | :--------- | :---------- | :-------- | :------- | :--- |
| **alpha** | **Sandbox.** For developers to verify behavior and try features. Things seen here might never go to production. Most bugs here can be ignored.| Unstable: Expect bugs | Internal developers | 0XX | 1.2.3-alpha04 (10203004) |
| **beta** | **Hand-off.** For developers to present finished features. Bugs found here should be reported and immediately addressed, if they relate to recent changes. | Unstable: Report bugs | Internal stakeholders | 2XX | 1.2.3-beta04 (10203204) |
| **release candidate** | **Hardening.** Final testing for an app release that we believe is ready to go live. The focus here is regression testing to ensure that new changes have not introduced instability in areas that were previously working.  | Stable: Hunt for bugs | External testers | 4XX | 1.2.3-rc04 (10203404) |
| **production** | **Dellivery.** Deliver new features to end users. Any bugs found here need to be prioritized. Some will require immediate attention but most can be worked into a future release. | Stable: Prioritize bugs | Public | 8XX | 1.2.3 (10203800) |

## Examples

This repo contains demos of isolated functionality that this SDK provides. They can be found in the examples folder

Examples can be found in the [Demo App](/Example/ZcashLightClientSample)

# License

Apache License Version 2.0
