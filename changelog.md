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


