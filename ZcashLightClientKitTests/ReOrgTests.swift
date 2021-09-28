//
//  ReOrgTests.swift
//  ZcashLightClientKit-Unit-Tests
//
//  Created by Francisco Gindre on 3/23/20.
//

import XCTest
@testable import ZcashLightClientKit

/**
basic reorg test.  Scan, get a reorg and then reach latest height.

* connect to dLWD
* request latest height -> receive 663250
* download and sync blocks from 663150 to 663250
* trigger reorg by calling API (no need to pass params)**
* request latest height -> receive 663251!
* download that block
* observe that the prev hash of that block does not match the hash that we have for 663250
* rewind 10 blocks and request blocks 663241 to 663251
*/
// swiftlint:disable implicitly_unwrapped_optional print_function_usage function_parameter_count
class ReOrgTests: XCTestCase {
    // TODO: Parameterize this from environment?
    // swiftlint:disable:next line_length
    let seedPhrase = "still champion voice habit trend flight survey between bitter process artefact blind carbon truly provide dizzy crush flush breeze blouse charge solid fish spread"
    // TODO: Parameterize this from environment
    let testRecipientAddress = "zs17mg40levjezevuhdp5pqrd52zere7r7vrjgdwn5sj4xsqtm20euwahv9anxmwr3y3kmwuz8k55a"
    let sendAmount: Int64 = 1000
    let defaultLatestHeight: BlockHeight = 663175
    let network = DarksideWalletDNetwork()
    let branchID = "2bb40e60"
    let chainName = "main"
    let mockLatestHeight = BlockHeight(663250)
    let targetLatestHeight = BlockHeight(663251)
    let walletBirthday = BlockHeight(663150)

    var birthday: BlockHeight = 663150
    var reorgExpectation = XCTestExpectation(description: "reorg")
    var coordinator: TestCoordinator!
    var syncedExpectation = XCTestExpectation(description: "synced")
    var sentTransactionExpectation = XCTestExpectation(description: "sent")
    var expectedReorgHeight: BlockHeight = 665188
    var expectedRewindHeight: BlockHeight = 665188

    override func setUpWithError() throws {
        try super.setUpWithError()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReOrgNotification(_:)),
            name: Notification.Name.blockProcessorHandledReOrg,
            object: nil
        )
        coordinator = try TestCoordinator(
            seed: seedPhrase,
            walletBirthday: birthday,
            channelProvider: ChannelProvider(),
            network: network
        )
        try coordinator.reset(saplingActivation: birthday, branchID: branchID, chainName: chainName)
        try coordinator.resetBlocks(dataset: .default)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        try? FileManager.default.removeItem(at: coordinator.databases.cacheDB)
        try? FileManager.default.removeItem(at: coordinator.databases.dataDB)
        try? FileManager.default.removeItem(at: coordinator.databases.pendingDB)
    }

    @objc func handleReOrgNotification(_ notification: Notification) {
        reorgExpectation.fulfill()
        guard let reorgHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewindHeight = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight else {
                XCTFail("malformed reorg userInfo")
                return
        }
        print("reorgHeight: \(reorgHeight)")
        print("rewindHeight: \(rewindHeight)")
        
        XCTAssertTrue(reorgHeight > 0)
        XCTAssertNoThrow(rewindHeight > 0)
    }
    
    func testBasicReOrg() throws {
        let mockLatestHeight = BlockHeight(663200)
        let targetLatestHeight = BlockHeight(663202)
        let reOrgHeight = BlockHeight(663195)
        let walletBirthday = WalletBirthday.birthday(with: 663150, network: network).height
        
        try basicReOrgTest(
            baseDataset: .beforeReOrg,
            reorgDataset: .afterSmallReorg,
            firstLatestHeight: mockLatestHeight,
            reorgHeight: reOrgHeight,
            walletBirthday: walletBirthday,
            targetHeight: targetLatestHeight
        )
    }
    
    func testTenPlusBlockReOrg() throws {
        let mockLatestHeight = BlockHeight(663200)
        let targetLatestHeight = BlockHeight(663250)
        let reOrgHeight = BlockHeight(663180)
        let walletBirthday = WalletBirthday.birthday(with: BlockHeight(663150), network: network).height
        
        try basicReOrgTest(
            baseDataset: .beforeReOrg,
            reorgDataset: .afterLargeReorg,
            firstLatestHeight: mockLatestHeight,
            reorgHeight: reOrgHeight,
            walletBirthday: walletBirthday,
            targetHeight: targetLatestHeight
        )
    }
    
    func basicReOrgTest(
        baseDataset: DarksideDataset,
        reorgDataset: DarksideDataset,
        firstLatestHeight: BlockHeight,
        reorgHeight: BlockHeight,
        walletBirthday: BlockHeight,
        targetHeight: BlockHeight
    ) throws {
        do {
            try coordinator.reset(saplingActivation: birthday, branchID: branchID, chainName: chainName)
            try coordinator.resetBlocks(dataset: .predefined(dataset: .beforeReOrg))
            try coordinator.applyStaged(blockheight: firstLatestHeight)
        } catch {
            XCTFail("Error: \(error)")
            return
        }

        let firstSyncExpectation = XCTestExpectation(description: "firstSyncExpectation")
        
        /**
        download and sync blocks from walletBirthday to firstLatestHeight
        */
        var synchronizer: SDKSynchronizer?
        try coordinator.sync(completion: { synchro in
            synchronizer = synchro
            firstSyncExpectation.fulfill()
        }, error: self.handleError)
       
        wait(for: [firstSyncExpectation], timeout: 5)
        
        guard let syncedSynchronizer = synchronizer else {
            XCTFail("nil synchronizer")
            return
        }

        /**
        verify that mock height has been reached
        */
        var latestDownloadedHeight = BlockHeight(0)
        XCTAssertNoThrow(try { latestDownloadedHeight = try syncedSynchronizer.initializer.downloader.latestBlockHeight() }())
        XCTAssertTrue(latestDownloadedHeight > 0)
        
        /**
        trigger reorg!
        */
        try coordinator.resetBlocks(dataset: .predefined(dataset: reorgDataset))
        try coordinator.applyStaged(blockheight: targetHeight)
     
        /**
        request latest height -> receive targetHeight!
        download that block
        observe that the prev hash of that block does not match the hash that we have for firstLatestHeight
        rewind 10 blocks and request blocks targetHeight-10 to targetHeight
        */
        let secondSyncExpectation = XCTestExpectation(description: "second sync")
        
        sleep(2)
        try coordinator.sync(
            completion: { _ in
                secondSyncExpectation.fulfill()
            },
            error: self.handleError
        )
        
        // now reorg should happen and reorg notifications and idle notification should be triggered
        
        wait(for: [reorgExpectation, secondSyncExpectation], timeout: 5)
        
        // now everything should be fine. latest block should be targetHeight
        
        XCTAssertNoThrow(try { latestDownloadedHeight = try syncedSynchronizer.initializer.downloader.latestBlockHeight() }())
        XCTAssertEqual(latestDownloadedHeight, targetHeight)
    }
    
    @objc func processorHandledReorg(_ notification: Notification) {
        XCTAssertNotNil(notification.userInfo)
        if let reorg = notification.userInfo?[CompactBlockProcessorNotificationKey.reorgHeight] as? BlockHeight,
            let rewind = notification.userInfo?[CompactBlockProcessorNotificationKey.rewindHeight] as? BlockHeight {
            XCTAssertTrue( rewind <= reorg )
            reorgExpectation.fulfill()
        } else {
            XCTFail("CompactBlockProcessor reorg notification is malformed")
        }
    }
    
    func handleError(_ error: Error?) {
        guard let testError = error else {
            XCTFail("failed with nil error")
            return
        }
        XCTFail("Failed with error: \(testError)")
    }
}
