# Performance Testing
### Intro
Benchmarking the SDK is one of the key focuses of `SDKMetrics` API. The most important operation of the SDK is the ability to synchronize blocks in order to see transactions, right balances and to send & receive funds. In short, be in sync with the mainnet blockchain. Synchronization consists of several sub-operations like downloading the blocks, validating & scanning, etc.

### Benchmarking the Synchronization
The initial work on benchmarking/performance testing allows us to properly measure times spent in sub-operations of a synchronization. There will be iterations and enhancements and ideally fully automated solution one day but for now we rely on manual approach.

### SDKMetrics
`SDKMetrics` is the public interface on the SDK side allowing users to get the synchronization related metrics. It's a shared singleton and you can access it via
```swift
SDKMetrics.shared
```
By default the gathering of the data is turned of so anything reported inside the SDK is simply ignored. You need to call
```swift
SDKMetrics.shared.enableMetrics()
```
in order to allow `SDKMetrics` to actually collect the RAW data. There's a counterpart API for the enablement, called
```swift
SDKMetrics.shared.disableMetrics()
```
This method turns the `SDKMetrics` off from collecting and also flushes all the so far collected RAW data. 
Like we said, the SDK is automatically reporting sub-operation metrics. The reports are collected and held in memory, split by the operation:
```swift
enum Operation {
    case downloadBlocks                 // download of the blocks
    case validateBlocks                 // validation of the downloaded blocks
    case scanBlocks                     // scanning of the downloaded blocks
    case enhancement                    // enhancement of the transactions
    case fetchUTXOs                     // fetching the UTXOs
}
```
Every report is represented by a struct:
```swift
struct BlockMetricReport: Equatable {
    startHeight: BlockHeight            // start of the range to be processed
    progressHeight: BlockHeight         // latest processed height
    targetHeight: BlockHeight           // end of the range to be processed
    batchSize: Int                      // size of the batch to be processed
    startTime: TimeInterval             // when the operation started
    endTime: TimeInterval               // when the operation finished
    duration: TimeInterval              // computed property to provide duration
}
```
`SDKMetrics` holds the reports in a dictionary where keys are the operations. You can receive the data via either of the following methods.
```swift
// Get all reports for the specific Operation
SDKMetrics.shared.popBlock(operation: Operation, flush: Bool = false) -> [BlockMetricReport]?

// Get the whole dictionary of collected data
SDKMetrics.shared.popAllBlockReports(flush: Bool = false) -> [Operation : [BlockMetricReport]]
```
Notice `flush` to be set to false by default. Collection the data leaves it in memory but you can clear it out of the memory by setting `flush` to `true`. Such option is handy when you plan to start to collect a new set of data.

These two `pop` methods simply returns RAW data from the `SDKMetrics` so post-processing of the data is up to the caller. There are extension methods that help with the accumulation of reports and provide decent post-processing for typical use cases though.

### SDKMetrics extension
Post-processing the array of reports per `Operation` or more general a dictionary of all arrays of reports may be time consuming, especially when you need to know just the times `Operation`s have taken. For this specific needs we introduce `CumulativeSummary` struct:
```swift
struct CumulativeSummary: Equatable {
    downloadedBlocksReport: ReportSummary?
    validatedBlocksReport: ReportSummary?
    scannedBlocksReport: ReportSummary?
    enhancementReport: ReportSummary?
    fetchUTXOsReport: ReportSummary?
    totalSyncReport: ReportSummary?
```
where `ReportSummary` represents:
```swift
struct ReportSummary: Equatable {
    minTime: TimeInterval
    maxTime: TimeInterval
    avgTime: TimeInterval
```
As you can see `CumulativeSummary` basically holds `min`, `max` and `avg` times per `Operation`. To generate such summary you call:
```swift
// Get the cumulative summary of the collected data
SDKMetrics.shared.cumulativeSummary() -> CumulativeSummary
```
There is a specific use case we want to mention, imagine you want to run a performance test that calls synchronization several times and you want to measure all runs separately and process runs afterwards. You either call `cumulativeSummary()` and re-enable the metrics to flush the data out and post-process collected summaries on your own or you can take advantage of 2 more methods available:
```swift
// Generates `CumulativeSummary` and stores it in memory & clears out data
SDKMetrics.shared.cumulateReportsAndStartNewSet()

// Merges all cumulativeSummaries into one
SDKMetrics.shared.summarizedCumulativeReports() -> CumulativeSummary?
```
So typical use case of these methods is sketched in the following pseudo code
```swift
    SDKMetrics.shared.enableMetrics()
    
    for run in 1...X {
        // ensure fresh start of synchronization

        // synchronize

        // collect data for this run and start new set
        SDKMetrics.shared.cumulateReportsAndStartNewSet()
    }

    // collect final data as a merge of all runs
    let finalSummary = SDKMetrics.shared.summarizedCumulativeReports()

    SDKMetrics.shared.disableMetrics()
```
Printed out example of the `finalSummary`:
```
downloadedBlocksTimes: min: 0.002303004264831543 max: 0.9062199592590332 avg: 0.14520481750369074
validatedBlocksTimes: min: 0.01760399341583252 max: 0.019036054611206055 avg: 0.0178409144282341
scannedBlocksTimes: min: 0.045277953147888184 max: 0.5136369466781616 avg: 0.2530662305653095
enhancementTimes: min: 0.0 max: 0.0 avg: 0.0
fetchUTXOsTimes: min: 1.9073486328125e-06 max: 2.09808349609375e-05 avg: 3.166496753692627e-06
totalSyncTimes: min: 7.222689986228943 max: 10.718868017196655 avg: 8.997062936425209
```

### Performance tests
We encourage you to visit `Tests/PerformanceTests/` folder and check `SynchronizerTests` where we do exactly what is mentioned in this doc. We run synchronization for specific range of 100 blocks 5 times, measure every run separately and merge results together in the end. The `SDKMetrics` and `SynchronizerTests` lay down foundations for the future automatization of performance testing.
