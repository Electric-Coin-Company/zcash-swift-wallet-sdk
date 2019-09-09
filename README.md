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
