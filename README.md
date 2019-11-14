# Zcash iOS Framework
A Zcash Lightweight Client SDK for iOS


# Build dependencies

Install [Rust](https://www.rust-lang.org/learn/get-started), and then `cargo-lipo`:

```
$ cargo install cargo-lipo
$ rustup target add aarch64-apple-ios x86_64-apple-ios
```

# Cocoapods Support

```` ruby
use_frameworks!

pod 'ZcashLightClientKit' 
````

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

#### _function_name  referenced from...
if you get a build error similar to ```_function_name  referenced from...``` 

* on your project root directory *
1. remove the 'Pods' directory ``` rm -rf Pods/```
2. delete derived data and clean
3. run ```pod install```
4. build 


# License 
Apache License Version 2.0
