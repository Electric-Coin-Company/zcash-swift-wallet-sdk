# 0.16.3-beta
 - [#436] Add checkpoint with a lower interval on mainnet (#437)
 This adds checkpoint at a 2500 block interval to help reduce scan times
 on new wallets
# 0.16.2-beta
- [#418] "Swift.EncodingError.InvalidValue Encoding an Int64 is not supported" (#430)
This fixes Cocoapods clients pointing to SQLite 0.12.2 instead of using 0.13
the former does not support custom encoding of Int64 and makes Zatoshi break

- [#428] make some helpers publicly accessible (#429)
# 0.16.1-beta
- [#422] Make Zatoshi extensions of `NSDecimalNumber` public (#423)
- [#419] Fix Unavailable Transport 14 when attempting to sync (#426)
 this changes timeout settings and Keepalive changes. 
 Recommended settings for lightwalletd.com are 60000ms singleCallTimeout
 on `LightWalletEndpoint`
 
- [#416] Update GRPC to 1.8.2 (#421)
# 0.16.0-beta
This version changes the way wallet birthdays are handled.
`WalletBirthday' struct is not longer public and has been renamed
to `Checkpoint`. 

`SynchronizerError` has a default `LocalizedError` compliance to 
help debug errors and display them to the user. This is a workaround
to get rid of cryptic errors that are being reported to maintainers and 
are subject to change in future versions.

- [#392] Synchronizer error 8. when syncing. (#413)
- [#398] Make WalletBirthday an internal type (#414)
- [#411] add Fresh checkpoints for release 0.16.0-beta (#412)
- [#406] some BirthdayTests fail for MacOS target (#410)
- [#404] Configure GRPC KeepAlive according to docs (#409)
# 0.15.1-beta (hotfix)
- [#432] create 0.15.1-beta with SQLite 0.13 
this build is a hotfix for cocoapods. which has the wront SQLite dependency
It moves it from 0.12.2 to 0.13


# 0.15.0-beta
** IMPORTANT ** This version no longer supports iOS 12
We've made a decision to make iOS 13 the minimum deployment target
in order to adopt and support Structured Concurrency and other important features
of the Swift language like Combine. 

- [#363] bump iOS minimum deployment target to iOS 13.0 (#407)
- [#381] Move Zatoshi and Amount Types to the SDK (#396)
This deprecates many methods on `SDKSynchronizer` using Zatoshi for amounts
instead of `Int64`. This exposes number formatters that conveniently provide
decimal conversion from `Zatoshi` to "human-readable" ZEC decimal numbers.

- [#397] Checkpoint format that supports NU5 TreeStates (#399)
`WalletBirthday` now have both `saplingTree` and `orchardTree` values. The
latter being Optional for checkpoints prior to Orchard activation height.

- [#401] DecodingError when refreshing pending transactions (#402)
- [#394] Update swift-grpc to 1.8.0 (#395)

other changes: renamed changelog.md to CHANGELOG.md
# 0.14.0-beta
- [#388] Integrate libzcashlc 0.0.3 to support v5 transaction parsing on NU5 activation
# 0.13.1-beta
- [#326] Load Checkpoint files from bundle.
This is great news! now checkpoints are loaded from files on the bundle instead of
hardcoding them on source files. This will make updates easier, less error prone,
and mostly automatable. 

- PR #356 Adds a caveat to SPM / Xcode integration in Readme
- [#367] Darksidewalletd for testing `shield_funds` 
- [#351] Write a Commit message Section for CONTRIBUTING.md
# 0.13.0-beta.2
- [Enhancement] Fix: make BlockProgress `.nullProgress` static property public for ECC Reference Wallet CombineSynchonizer 
# 0.13.0-beta.1
- [Enhancement] PR #338. Rust-less build. Check for new documentation on how to benefit from this huge change
- [Enhancement] Swift Package Manager Support!

# 0.12.0-beta.6
- [Enhancement] Fresh checkpoints

# 0.12.0-beta.5
- FIX fixes to Apple Silicon M1 builds

# 0.12.0-beta.4
- Fix: add parameter to ensure 10 confs when shielding.

# 0.12.0-beta.2
- [Fix] Issue #293 MaxAttemptsReached error surfaces when it's actually dismissable and the wallet is working fine
- [Enhancement] Add test to verify that a checksum invalid t-address fails to validate.

# 0.12.0-alpha.11
* [Enhancement] Network Agnostic build

#  0.12.0-alpha.10
* Fix: UNIQUE Constraint bug when coming from background. fixed and logged warning to keep investigating
* [New] latestScannedHeight added to SDKSynchronizer

# 0.12.0-alpha.9 
* CompactBlockProcessor states don't propagate correctly

# 0.12.0-alpha.8
* target height reporting enhancements

# 0.12.0-alpha.7
* improve status publishing for SDKSynchronizer
* [FIX] missingStartHeight error when scanning from sapling activation

# 0.12.0-alpha.6
* Make sapling parameters default url public

# 0.12.0-alpha.5
* add output files to build phase to avoid CI failures
* fix lint warnings

# 0.12.0-alpha.4
* Tests
* [Fix] Issue #289 main thread lock when validating the server
* [Fix] info single call times out all the time
* make sure operations cancel in a timely manner
* FigureNextBatchOperation.swift tests
* make range function static

# tag: 0.12.0-alpha.3
* getInfo service times out too soon
# 0.12.0-alpha.2
* FIX: processor stalls on reconnection
* Fix warnings
# 0.12.0-alpha.1
* Replace Status for SyncStatus
* fix tests
* Fix Demo App
* fetch operation does not cancel when the previous operations do
* Fix: operations start when they have been canceled already
* fix progress being > 1
* Synchronizing by phases, preview
* Add fetch UTXO operation to compact block processor
* CompactBlock batch download and stream download operation tests pass.

# 0.11.2 
* [FIX] Fix build for Apple Silicon (M1) #285 by @ealymbaev 

# 0.11.1
* [Enhancement] Rewind API has a `.quick` option
# 0.11.0
* [New] Shield Funds Feature
* [New] Get Transparent Balance for account
* [New] Z -> T Restore: transactions to transparent addresses are now restored when the user restores from seed or re-scans the wallet
* [New] [Preview] Unified Viewing Key Structure
* [New] Abstractions over Transparent Address and ShieldedAddress
* [FIX] `CompactBlockProcessor` validates LightdInfo from Lightwalletd
* [Enhancement] Add BlockTime to SDKSynchronizer updates
* [New] Db Migration for UVKs
* [FIX] Rewind API breaks on quick re-scan
* [Update] 37f2232: Update to gRPC-Swift 1.0.0

# 0.10.2
* Mainnet and Testnet Checkpoints 
# 0.10.1
* Mainnet Checkpoints
# 0.10.0
* [critical] Fix #255 #261 outgoing no-change transactions not reported as mined
* [NEW] Rewind API. Allow Wallet developers to rewind synchronizer and (eventually) rescan
* [NEW] Rust Welding 0.0.6 - using rust crates 0.5 and Data Access API
* [NEW] updated Logger API to use StaticString on line and function as many logging libraries do
* [FIX] Mac OS BIG SUR build fixed


# 0.9.4
* New: added viewing key derivation to Derivation Tool 
* Issue #252 - blockheight progress is latest height instead of upperbound of last scanned range
# 0.9.3
* added new checkpoints for mainnet
# 0.9.2
* Fix: memo string handling
# 0.9.1
* Fix: issue #240 reorg not catched because of ARC dealloc

# 0.9.0
* implement ZIP-313 reducing fees to 1000 zatoshi

# 0.8.0
* [IMPORTANT] Issue #237 Untie SDKSynchronizer from UIApplication Events
* Fix #236 fix CI problem
* Issue #176 operation gets cancelled when backgrounding
* Issue #136 on https://github.com/zcash/zcash-ios-wallet
* Issue #123 on https://github.com/zcash/zcash-ios-wallet
* PR from @ant013: Forcibly change the state to stopped when the handle cancels any task in OperationQueue
# 0.7.2
* Checkpoint for Mainnet 

# 0.7.1
* Issue 208 - Improve API method to request transaction history
* Added Found transaction notification to SDK Synchronizer
* Add darksidewalletd tests for foundTransactions notifications
* [CRITICAL] Fix sqlite crate canopy issue. Add a new checkpoint to aid testing
* FIX - UNIQUE constraint violation when an operation failed

# 0.7.0
Improvements: 
* #22 Sapling parameter downloader
* #201 Throw exception when seed can't be provided
* #204 Add DerivationTool to Initializer
* #205 Add IVK initialization capabilities to Initializer
* #206 [community request @esengulov] add extension function to identify inbound v. outbound txs on a client side
* #207 [community request @esengulov] Add extension function for timestamps on transactions  

# 0.6.4
* FIX: transaction details listing duplicate transactions on certain transactions with several outputs and inputs
* added checkpoints

# 0.6.3
* updated to gRPC-Swift 1.0.0-alpha19
* readme warning on issues with rustc 1.46.0
* improvement on build system to help switch network environment faster
# 0.6.2
* added new checkpoints for testnet and mainnet
# 0.6.1
* Updated librustzcash to support Canopy on testnet

# 0.6.0
* Error handling improvements (breaks API)
# 0.5.3
* Fixes #158 #132 #134 #135 #133

# 0.5.2
* update Librustzcash to point to master repo!
* enhance pending transaction handling (#160)
* Added memo demo! 
* automation!

# 0.5.1
* remove MnemonicKit dependency from tests
# 0.5.0
* Enable heartwood. (#138)
* Update LICENSE
* Switch to MnemonicSwift (#142)
* Issue 136 Null bytes in strings effectively truncate the string from … (#140)
* Fixes issue 136 - expiry height -1 on pending transactions (#139)
* Advanced Re Org tests + Balance tests (#137)
* CI doc mods (#116)
* Update issue templates
* Replace the threat model with the one on readthedocs (#131)
* Add bug report and feature request issue templates
* remove commit lock from podfile
* Canonical empty memo test (#112)
* Memo tests (#111)
* Decrypt transactions. Full wallet restore (#110)

# 0.4.0
* Updated GRPC dependency to Swift GRPC NIO. this change does not break any public interfaces

# 0.3.2

*  reorg testing (#104)
*  Docs - Fix typos and cleanup (#103)
*  ZcashRustBackend.decryptAndStoreTransaction() 
*  Enhance logging on compact block processor
*  parameterize helper method with constant

# 0.3.1
* Reverted  -> update librustzcash to commit 52d8b436300724bc4b83aa4a0c659ab34c3dbce7
# 0.3.0

* testing: fix test crash
* fix: updated sample code where interface changed
* ENHANCEMENT: Retry support + error management
* FIX: processor crashes when lightwalletd has not caught up with latest height
* Better error handing when scanning fails
* [IMPORTANT] update librustzcash to commit 52d8b436300724bc4b83aa4a0c659ab34c3dbce7
* improved docs Move read.me up a directory
* NEW: Integrate logging capabilities
* FIX: account initialization error
* ENHANCEMENT: Mainnet checkpoints (#88)

# 0.2.1
**IMPORTANT: this version contains a critical fix, upgrade to it as soon as possible**

* [CRITICAL] Fixed a hardcoded COIN_TYPE on lib.rs
* added mainnet checkpoints 


# 0.2.0 
_Warning: This changes might break interfaces on your project_

* upgraded to note-spending-v7
* fixed memory leak and blockrange error
* fixed memory cycles and leaks
* Fixed capture blocks retaining references
* fixed bug where compact block processor wouldn't reschedule
* add address validation functionality to Initializer
* Fixes to initializer, added v7 methods, documented API. Fixed compact block processor not initializing correctly upon new wallets.
* use "zip32 compliant" seed on demo app

# 0.1.3
Changes to createToAddress function to fix issues with paths that have spaces

Synchronizer:

change from computed variables to functions to allow throwing errors to clients

https://github.com/zcash/ZcashLightClientKit/pull/84


