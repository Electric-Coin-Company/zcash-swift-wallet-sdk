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

# Installation

## Swift Package Manager

Add a package with the source "https://github.com/zcash/ZcashLightClientKit.git" and from version `0.13.0` onwards in either Xcode's GUI or in your `Package.swift` file.

### Beta version support for Xcode projects

If you want to include a beta version of `ZCashLightClientKit` in an Xcode project e.g `0.13.0-beta.2` you will need to specify it with the commit sha instead as it does not appear that Xcode supports 'meta data' from semantic version strings for swift packages (at the time of writing).

## Cocoapods Support

Add `pod "ZcashLightClientKit", ~> "0.13.0-beta.2"` to the target you want to add the kit too.

# Testing

The best way to run tests is to open "Package.swift" in Xcode and use the Test panel and target an iOS device. Tests will build and run for a Mac target but are not currently working as expected.

There are three test targets grouped by external requirements:
1. `OfflineTests`
    - No external requirements.
2. `NetworkTests`
    - Require an active internet connection.
3. `DarksideTests`
    - Require an instance of `lightwalletd` to be running while the tests are being run, see below for some information on how to set up. (Darkside refers to a mode in lightwalletd that allows it to be updated to represent/mock different states of the underlying blockchain.)

## lightwalletd

The `DarksideTests` test target depend on a `lightwalletd` server instance running locally (or remotely). For convenience, we have added a universal (Mac) `lightwalletd` binary (in `Tests/lightwalletd/lightwalletd) and it can be run locally for use by the tests with the following command:

```
Tests/lightwalletd/lightwalletd --no-tls-very-insecure --data-dir /tmp --darkside-very-insecure --log-file /dev/stdout
```

You can find out more about running `lightwalletd`, from the main repo https://github.com/zcash/lightwalletd.

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
  
# Versioning

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
