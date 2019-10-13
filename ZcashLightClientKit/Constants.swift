//
//  Constants.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 13/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

/**
 * Miner's fee in zatoshi.
 */
let MINERS_FEE_ZATOSHI: BlockHeight = 10_000

/**
 * The number of zatoshi that equal 1 ZEC.
 */
let ZATOSHI_PER_ZEC: BlockHeight = 100_000_000

/**
 * The height of the first sapling block. When it comes to shielded transactions, we do not need to consider any blocks
 * prior to this height, at all.
 */
let SAPLING_ACTIVATION_HEIGHT: BlockHeight = 280_000

/**
 * The theoretical maximum number of blocks in a reorg, due to other bottlenecks in the protocol design.
 */
let MAX_REORG_SIZE = 100

/**
 * The amount of blocks ahead of the current height where new transactions are set to expire. This value is controlled
 * by the rust backend but it is helpful to know what it is set to and shdould be kept in sync.
 */
let EXPIRY_OFFSET = 20

//
// Defaults
//

/**
 * Default size of batches of blocks to request from the compact block service.
 */
let DEFAULT_BATCH_SIZE = 100

/**
 * Default amount of time, in milliseconds, to poll for new blocks. Typically, this should be about half the average
 * block time.
 */
let DEFAULT_POLL_INTERVAL: UInt64 = 75_000

/**
 * Default attempts at retrying.
 */
let DEFAULT_RETRIES = 5

/**
 * The default maximum amount of time to wait during retry backoff intervals. Failed loops will never wait longer than
 * this before retyring.
 */
let DEFAULT_MAX_BACKOFF_INTERVAL: TimeInterval = 600

/**
 * Default number of blocks to rewind when a chain reorg is detected. This should be large enough to recover from the
 * reorg but smaller than the theoretical max reorg size of 100.
 */
let DEFAULT_REWIND_DISTANCE = 10

/**
 * The number of blocks to allow before considering our data to be stale. This usually helps with what to do when
 * returning from the background and is exposed via the Synchronizer's isStale function.
 */
let DEFAULT_STALE_TOLERANCE = 10

/**
 Default Name for LibRustZcash data.db
 */
let DEFAULT_DATA_DB_NAME = "data.db"

/**
Default Name for Compact Block caches db
*/
let DEFAULT_CACHES_DB_NAME = "caches.db"
