# unreleased 
- [#724] Switch from event based notifications to state based notifications

    The `SDKSynchronizer` no longer uses `NotificationCenter` to send notifications.
Notifications are replaced with `Combine` publishers. Check the migrating document and
documentation in the code to get more information.

- [#826] Change how the SDK is initialized
    
    - `viewingKeys` and `walletBirthday` are removed from `Initializer` constuctor. These parameters
are moved to `SDKSynchronizer.prepare` function.
    - Constructor of the `SDKSynchronizer` no longer throws exception.
    - Any value emitted from `lastState` stream before `SDKSynchronizer.prepare` is called has 
`latestScannedHeight` set to 0.
    - `Initializer.initialize` function isn't public anymore. To initialize SDK call `SDKSynchronizer.prepare` 
instead. 


# 0.19.1-beta
## Checkpoints added
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/2002500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/2005000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/2007500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/2010000.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2250000.json
````
## Fixed
- [#821] `failedToWriteMetadata` at sync startup
contains no public API changes.
Adds `func shouldClearBlockCacheAndUpdateInternalState() -> BlockHeight?` to `SyncRanges`
so that the compact block processor can advert internal states that are not consistent and
recover from such state. 

For concrete examples check out the tests in:
`Tests/NetworkTests/CompactBlockProcessorTests.swift`


## Deleted
Removed linter binary from repository

# 0.19.0-beta
- [#816] Improve how rewind call can be used

    `SDKSynchronizer.rewind(policy:)` function can be now called anytime. It returns `AnyPublisher` which
completes or fails when the rewind is done. For more details read the documentation for this method 
in the code.

- [#801] Improve how wipe call can be used

    `SDKSynchronizer.wipe()` function can be now called anytime. It returns `AnyPublisher` which
completes or fails when the wipe is done. For more details read the documentation for this method 
in the code.

- [#793] Send synchronizerStopped notification only when sync process stops
    
    `synchronizerStopped` notification is now sent after the sync process stops. It's
not sent right when `stop()` method is called.

- [#795] Include sapling-spend file into bundle for tests
    
    This is only an internal change and doesn't change the behavior of the SDK. `Initializer`'s
constructor has a new parameter `saplingParamsSourceURL`. Use `SaplingParamsSourceURL.default` 
value for this parameter.

- [#764] Refactor communication between components inside th SDK

    This is mostly an internal change. A consequence of this change is that all the notifications
delivered via `NotificationCenter` with the prefix `blockProcessor` are now gone. If affected
notifications were used in your code use notifications with the prefix `synchronizer` now. 
These notifications are defined in `SDKSynchronizer.swift`.

- [#759] Remove Jazz-generated HTML docs

    We remove these documents since they are outdated and we rely on the docs in the 
code itself.

- [#726] Modularize GRPC layer

    This is mostly internal change. `LightWalletService` is no longer public. If it
is used in your code replace it by using `SDKSynchronizer` API.

- [#770] Update GRPC swift library
    This updates to GRPC-Swift 1.14.0.


Checkpoints added:

Mainnet:
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1965000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1967500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1970000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1972500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1975000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1977500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1980000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1982500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1985000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1987500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1990000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1992500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1995000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1997500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/2000000.json
````

Testnet:
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2210000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2220000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2230000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2240000.json
````
## File system backed block cache

File system based block cache. Compact blocks will now be stored
on the file system. Caller must provide a `URL` pointing to the 
filesystem root directory where the fsBlock cache is. this directory
is expected to contain a `/blocks` sub-directory with the blocks stored
in the convened filename format `{height}-{hash}-compactblock`. This directory
must be granted both read and write permissions.

the file system cache will have a "bookkeeping" database that the rust
welding layer will use to know the state of the cache and locate the 
cached compact blocks. This directory can be deleted provided that the
Compactblock processor or Synchronizer are not running. Upon deletion 
caller is responsible for initializing these objects for the cache to 
be created. 

Implementation notes: Users of the SDK will know the path they will 
provide but must assume no behavior whatsoever or rely on the cached 
information in any way, since it is an internal state of the SDK. 
Maintainers might provide no support for problems related to speculative
use of the file system cache. If you consider your application needs any
other information than the one available through public APIs, please 
file the corresponding feature request.

### Added

- `Synchronizer.shieldFunds(spendingKey:memo:shieldingThreshold)` shieldingThreshold
was added allowing wallets to manage their own shielding policies.
    
### Removed
- `InitializerError.cacheDbMigrationFailed`

### Deprecations
CacheDb references that were deprecated instead of **deleted** are pointing out
that they should be useful for you to migrate from using cacheDb.

- `ResourceProvider.cacheDbURL` deprecated but left for one release cycle for clients 
to move away from cacheDb.

- `NetworkConstants.defaultCacheDbName` deprecated but left for one release cycle for clients 
to move away from cacheDb.

## Other Issues Fixed by this PR:

- [#587] ShieldFundsTests:
 - https://github.com/zcash/ZcashLightClientKit/issues/720
 - https://github.com/zcash/ZcashLightClientKit/issues/587
 - https://github.com/zcash/ZcashLightClientKit/issues/667

- [#443] Delete blocks from cache after processing them
    Closes https://github.com/zcash/ZcashLightClientKit/issues/443
- [#754] adopt name change in libzashlc package that fixes a deprecation in SPM
    Closes https://github.com/zcash/ZcashLightClientKit/issues/754

# 0.18.1-beta
 - [#767] implement getRecipients() for Synchronizer.
    
This implements `getRecipients()` function which retrieves the possible
recipients from a sent transaction. These can either be addresses or
internal accounts depending on the transaction being a shielding tx
or a regular outgoing transaction.

 Other changes:
    - Fix version of zcash-light-client-ffi to 0.1.1
    
    - Enhance error reporting on a test make Mock comply with protocol
# 0.18.0-beta

## Farewell Cocoapods.
- [#612] Remove Support for Cocoapods (#706)

It wouldn't have been possible to release an SDK without you, pal.

We are moving away from Cocoapods since our main dependencies, SwiftGRPC
and SWIFT-NIO are. We don't have much of a choice. 

We've been communicating this for a long time. Although, if you really need Cocoapods,
please let us know by opening an issue in our repo and we'll talk about it.


## New Checkpoints 
Checkpoints 

Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1937500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1940000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1942500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1945000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1947500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1950000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1952500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1955000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1957500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1960000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1962500.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2180000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2190000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2200000.json
````

## Bugfixes

- [#645] Default rewind after ReOrg is 20 blocks when it should be 10
    This fixes an issue where the default reorg was 20 blocks rewind instead of 10. The
reorg count was incremented before calling the rewind height computing function.

## Use Librustzcash database views to query and represent transactions
 
- [#556] Change data structures which represent transactions.

    These data types are gone: `Transaction`, `TransactionEntity`, `ConfirmedTransaction`, 
`ConfirmedTransactionEntity`. And these data types were added: `ZcashTransaction.Overview`, 
`ZcashTransaction.Received`, `ZcashTransaction.Sent`. 

    New data structures are very similar to the old ones. Although there many breaking changes.
The APIs of the `SDKSynchronizer` remain unchanged in their behavior. They return different 
data types. **When adopting this change, you should check which data types are used by methods 
of the `SDKSynchronizer` in your code and change them accordingly.**

    New transaction structures no longer have a `memo` property. This responds to the fact that 
Zcash transactions can have either none or multiple memos. To get memos for the transaction 
the `SDKSynchronizer` has now new methods to fetch those:
    - `func getMemos(for transaction: ZcashTransaction.Overview) throws -> [Memo]`, 
    - `func getMemos(for receivedTransaction: ZcashTransaction.Received) throws -> [Memo]`
    - `func getMemos(for sentTransaction: ZcashTransaction.Sent) throws -> [Memo]`
    
## CompactBlockProcessor is now internal
- [#671] Make CompactBlockProcessor Internal.

    The CompactBlockProcessor is no longer a public class/API. Any direct access will
end up as a compiler error. Recommended way how to handle things is via `SDKSynchronizer`
from now on. The Demo app has been updated accordingly as well.

## We've changed how we download and scan blocks. Status reporting has changed.

- [#657] Change how blocks are downloaded and scanned. 

    In previous versions, the SDK first downloaded all the blocks and then it
scanned all the blocks. This approach requires a lot of disk space. The SDK now 
behaves differently. It downloads a batch of blocks (100 by default), scans those, and
removes those blocks from the disk. And repeats this until all the blocks are processed.

    `SyncStatus` was changed. `.downloading`, `.validating`, and `.scanning` symbols
were removed. And the `.scanning` symbol was added. The removed phases of the sync 
process are now reported as one phase. 

    Notifications were also changed similarly. These notifications were
removed: `SDKSynchronizerDownloading`, `SDKSyncronizerValidating`, and `SDKSyncronizerScanning`.
And the `SDKSynchronizerSyncing` notification was added. The added notification replaces
the removed notifications.
        
## New Wipe Method to delete wallet information. Use with care. 
- [#677] Add support for wallet wipe into SDK. Add new method `Synchronizer.wipe()`. 

## Benchmarking APIs: A primer
- [#663] Foundations for the benchmarking/performance testing in the SDK. 

    This change presents 2 building blocks for the future automated tests, consisting
of a new SDKMetrics interface to control flow of the data in the SDK and 
new performance (unit) test measuring synchronization of 100 mainnet blocks. 

# 0.17.6-beta
- [#756] 0.17.5-beta updates to libzcashlc 0.2.0 when it shouldn't

Updated checkpoints to the ones present in 0.18.0-beta
# 0.17.5-beta

Update checkpoints 

Mainnet

````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1912500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1915000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1917500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1920000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1922500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1925000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1927500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1930000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1932500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1935000.json
````

Tesnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2150000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2160000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2170000.json
````

# 0.17.4-beta
- [#665] Fix testShieldFunds() `get_transparent_balance` error
updates `libzcashlc` to `0.1.1` to fix an error where getting a 
transparent balance on an empty database would fail.
# 0.17.3-beta
- [#646] SDK sync process resumes to previously saved block height
This change adds an internal storage test on UserDefaults that tells the 
SDK where sync was left off when cancelled whatever the reason for it
to restart on a later attempt. This fixes some issues around syncing
long block ranges in several attempts not enhancing the right transactions
because the enhancing phase would only consider the last range scanned.
This only fixes the situation where rewinding the SDK would cause the 
whole database to be cleared instead and syncing to be restarted from 
scratch (issue [#660]).

- commit `3b7202c` Fix `testShieldFunds()` dataset loading issue. (#659)
New Checkpoints

Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1897500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1900000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1902500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1905000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1907500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1910000.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2140000.json
````


New Checkpoint for `testShieldFunds()`
```
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1631000.json
```

# 0.17.2-beta
- [#660] Fix the situation when any rewind causes full rescan

# 0.17.1-beta
- [#651] Change the rewind behavior. Now if the rewind is used while the sync process is in progress then an exception is thrown.
- [#616] Download Stream generates too many updates on the main thread
> **WARNING**: Notifications from SDK are no longer delivered on main thread.

- [#585] Fix RewindRescanTests (#656)
- Cleanup warnings (#655)
- [#637] Make sapling parameter download part of processing blocks (#650)
- [#631] Verify SHA1 correctness of Sapling files after downloading (#643)
- Add benchmarking info to SyncBlocksViewController (#649)
- [#639] Provide an API to estimate TextMemo length limit correctly (#640)
- [#597] Bump up SQLite Swift to 0.14.1 (#638)
- [#488] Delete cache db when sync ends

- Added Checkpoints

Mainnet 
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1882500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1885000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1887500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1890000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1892500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1895000.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2120000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2130000.json
````

# Summary of 0.17.0-beta

- [#321] Validate UA
- [#384] Adopt Type Safe Memos in the FFI and SDK
- [#355] Update lib.rs to lastest librustzcash master
- [#373] Demo App shows ZEC balances in scientific notation
- [#380] One of the initAccountsTable() is dead code (except for tests) 
- [#374] XCTest don't load Resources from the module's bundle
- [#375] User can't go twice in a row to SendFundsViewController
- [#490] Rebase long dated PRs on top of the feature branches
- [#510] Change references of Shielded address to Sapling Address
- [#511] Derivation functions should only return a single resul
- [#512] Remove derivation of t-address from pubkey
- [#520] Use UA Test Vector for Recipient Test
- [#544] Change Demo App to use USK and new rolling addresses
- [#602] Improve error logging for InitializerError and RustWeldingError
- [#579] Fix database lock
- [#595] Update Travis to use Xcode 14
- [#592] Fix various tests and deleted some that are not useful anymore
- [#523] Make a CompactBlockProcessor an Actor
- [#593] Fix testSmallDownloadAsync test
- [#577] Fix: reduce batch size when reaching increased load part of the chain
- [#575] make Memo and MemoBytes parameters nullable so they can be omitted 
when sending to transparent receivers.
- commit `1979e41` Fix pre populated Db to have transactions from darksidewalletd seed
- commit `a483537` Ensure that the persisted test database has had migrations applied.
- commit `1273d30` Clarify & make regular how migrations are applied.
- commit `78856c6` Fix: successive launches of the application fail because the closed range of the migrations to apply would be invalid (lower range > that upper range)
- commit `7847a71` Fix incorrect encoding of optional strings in PendingTransaction.
- commit `789cf01` Add Fee field to Transaction, ConfirmedTransaction, ReceivedTransactions and Pen dingTransactions. Update Notes DAOs with new fields
- commit `849083f` Fix UInt32 conversions to SQL in PendingTransactionDao
- commit `fae15ce` Fix sent_notes.to_address column reference.
- commit `23f1f5d` Merge pull request #562 from zcash/fix_UnifiedTypecodesTests
- commit `30a9c06` Replace `db.run` with `db.execute` to fix migration issues
- commit `0fbf90d` Add migration to re-create pending_transactions table with nullable columns.
- commit `36932a2` Use PendingTransactionEntity.internalAccount for shielding.
- commit `f5d7aa0` Modify PendingTransactionEntity to be able to represent internal shielding tx.
- [#561] Fix unified typecodes tests
- [#530] Implement ability to extract available typecodes from UA

- Added Checkpoints

Mainnet 
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1872500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1875000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1877500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1880000.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2110000.json
````

# 0.17.0-beta.rc1
- Added Checkpoints

Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1852500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1855000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1857500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1860000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1862500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1865000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1867500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1870000.json
````
Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2020000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2030000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2040000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2050000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2060000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2070000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2080000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2090000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2100000.json
````

# 0.17.0-alpha.5
- point to libzcashlc 0.1.0-beta.3. This fixes an issue spending change notes 
# 0.17.0-alpha.4
- point to libzcashlc 0.1.0-beta.2

# 0.17.0-alpha.3
- [#602] Improve error logging for InitializerError and RustWeldingError

# 0.17.0-alpha.2
- [#579] Fix database lock
- [#592] Fix various tests and deleted some that are not useful anymore
- [#581] getTransparentBalanceForAccount error not handled

# 0.17.0-alpha.1
See MIGRATING.md

# 0.16-13-beta
- [#597] SDK does not build with SQLite 0.14
# 0.16.12-beta
Checkpoints added:
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1832500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1835000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1837500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1840000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1842500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1845000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1847500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1850000.json
````        
# 0.16.11-beta
Checkpoints added:
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1812500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1815000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1817500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1820000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1822500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1825000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1827500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1830000.json
````
# 0.16.10-beta
- [#532] [0.16.x-beta] Download does not stop correctly

Issue Reported:

When the synchronizer is stopped, the processor does not cancel
the download correctly. Then when attempting to resume sync, the
synchronizer is not on `.stopped` and can't be resumed

this doesn't appear to happen in `master` branch that uses
structured concurrency for operations.

Fix:
This commit makes sure that the download streamer checks cancelation
before processing any block, or getting called back to report progress

Checkpoints added:
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1807500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1810000.json
````

# 0.16.9-beta
Checkpoints added:
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1787500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1790000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1792500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1795000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1797500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1800000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1802500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1805000.json
````
# 0.16.8-beta
Checkpoints added:
Mainnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1775000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1777500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1780000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1782500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1785000.json
````

Testnet
````
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2000000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/2010000.json
````

# 0.16.7-beta
- [#455] revert queue priority downgrade changes from [#435] (#456)
    
This reverts queue priority changes from commit `a5d0e447748257d2af5c9101391dd05a5ce929a2` since we detected it might prevent downloads to be scheduled in a timely fashion

Checkpoints added:
Mainnet
```
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1757500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1760000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1762500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1765000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1767500.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1770000.json
Sources/ZcashLightClientKit/Resources/checkpoints/mainnet/1772500.json
```

Testnet
```
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/1980000.json
Sources/ZcashLightClientKit/Resources/checkpoints/testnet/1990000.json
```

# 0.16.6-beta
- There's a problem with 0.16.5-beta hash. Re-releasing 
# 0.16.5-beta
- [#449] Use CompactBlock Streamer download instead of batch downloads (#451)
This increases the speed of downloads significantly while reducing the memory footprint.
- [#435] thread sanitizer issues (#448)
Issues related to Thread Sanitizer warnings

Also new Checkpoint for 1755000 on mainnet
# 0.16.4-beta
- [#444] Syncing Restarts to zero when the wallet is wiped and synced from zero in one go. (#445)
- [#440] Split constants for Download Batches and Scanning Batches (#441)
This change was done to aleviate memory load when downloading large blocks.
Default download batch constant is deprecated in favor of `DefaultDownloadBatch` and 
`DefaultScanningBatch`
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


