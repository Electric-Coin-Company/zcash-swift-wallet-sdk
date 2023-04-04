//
//  SyncBlocksListViewController.swift
//  ZcashLightClientSample
//
//  Created by Michal Fousek on 24.03.2023.
//  Copyright © 2023 Electric Coin Company. All rights reserved.
//

import Combine
import Foundation
import UIKit
import ZcashLightClientKit

// swiftlint:disable force_try force_cast

class SyncBlocksListViewController: UIViewController {
    @IBOutlet var table: UITableView!
    @IBOutlet var loadingLabel: UILabel!
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!

    var synchronizers: [Synchronizer] = []
    var synchronizerData: [DemoAppConfig.SynchronizerInitData] = []
    var cancellables: [AnyCancellable] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        table.isHidden = true
        loadingLabel.isHidden = false
        loadingIndicator.startAnimating()

        navigationItem.title = "List of synchronizers"

        synchronizerData = [
            DemoAppConfig.SynchronizerInitData(alias: .default, birthday: DemoAppConfig.defaultBirthdayHeight, seed: DemoAppConfig.defaultSeed)
        ] + DemoAppConfig.otherSynchronizers

        makeSynchronizers() { [weak self] synchronizers in
            self?.synchronizers = synchronizers
            self?.table.reloadData()

            self?.loadingLabel.isHidden = true
            self?.loadingIndicator.stopAnimating()
            self?.table.isHidden = false

            self?.subscribeToSynchronizers()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancellables = []
        Task(priority: .userInitiated) {
            for synchronizer in synchronizers {
                await synchronizer.stop()
            }
        }
    }

    private func didTapOnButton(index: Int) async {
        Task { @MainActor in
            let synchronizerData = synchronizerData[index]
            let synchronizer = synchronizers[index]
            let syncStatus = synchronizer.latestState.syncStatus

            loggerProxy.debug("Processing synchronizer with alias \(synchronizer.alias.description) \(index)")

            switch syncStatus {
            case .stopped, .unprepared, .synced, .disconnected, .error:
                do {
                    if syncStatus == .unprepared {
                        let derivationTool = AppDelegate.shared.sharedWallet.makeDerivationTool()
                        let spendingKey = try await derivationTool.deriveUnifiedSpendingKey(seed: synchronizerData.seed, accountIndex: 0)
                        let viewingKey = try await derivationTool.deriveUnifiedFullViewingKey(from: spendingKey)

                        _ = try! await synchronizer.prepare(
                            with: synchronizerData.seed,
                            viewingKeys: [viewingKey],
                            walletBirthday: synchronizerData.birthday
                        )
                    }

                    try await synchronizer.start(retry: false)
                } catch {
                    loggerProxy.error("Can't start synchronizer: \(error)")
                }
            case .syncing, .enhancing, .fetching:
                await synchronizer.stop()
            }
        }
    }

    private func makeSynchronizers(completion: @escaping ([Synchronizer]) -> Void) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return completion([]) }
            let otherSynchronizers = DemoAppConfig.otherSynchronizers.map { self.makeSynchronizer(from: $0) }
            let synchronizers = [AppDelegate.shared.sharedSynchronizer] + otherSynchronizers

            DispatchQueue.main.async {
                completion(synchronizers)
            }
        }
    }

    private func makeSynchronizer(from data: DemoAppConfig.SynchronizerInitData) -> Synchronizer {
        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: try! fsBlockDbRootURLHelper(),
            dataDbURL: try! dataDbURLHelper(),
            pendingDbURL: try! pendingDbURLHelper(),
            endpoint: DemoAppConfig.endpoint,
            network: kZcashNetwork,
            spendParamsURL: try! spendParamsURLHelper(),
            outputParamsURL: try! outputParamsURLHelper(),
            saplingParamsSourceURL: SaplingParamsSourceURL.default,
            alias: data.alias,
            logLevel: .debug
        )

        return SDKSynchronizer(initializer: initializer)
    }

    private func subscribeToSynchronizers() {
        for (index, synchronizer) in synchronizers.enumerated() {
            synchronizer.stateStream
                .throttle(for: .seconds(0.3), scheduler: DispatchQueue.main, latest: true)
                .sink(
                    receiveValue: { [weak self] _ in
                        self?.table.reloadRows(at: [IndexPath(item: index, section: 0)], with: .none)
                    }
                )
                .store(in: &cancellables)
        }
    }
}

extension SyncBlocksListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return synchronizers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: "SynchronizerCell", for: indexPath) as! SynchronizerCell
        let synchronizer = synchronizers[indexPath.row]

        let synchronizerStatus = synchronizer.latestState.syncStatus

        cell.alias.text = synchronizer.alias.description
        cell.status.text = synchronizerStatus.text

        let image: UIImage?
        switch synchronizerStatus {
        case .unprepared, .synced, .stopped, .disconnected, .error:
            image = UIImage(systemName: "play.circle")
        case .syncing, .enhancing, .fetching:
            image = UIImage(systemName: "stop.circle")
        }

        cell.button.setTitle("", for: .normal)
        cell.button.setTitle("", for: .highlighted)
        cell.button.setImage(image, for: .normal)
        cell.button.setImage(image, for: .highlighted)

        cell.indexPath = indexPath
        cell.didTapOnButton = { [weak self] indexPath in
            Task {
                await self?.didTapOnButton(index: indexPath.row)
            }
        }

        return cell
    }
}

extension SyncStatus {
    var text: String {
        switch self {
        case let .syncing(progress):
            return "Syncing 🤖 \(floor(progress.progress * 1000) / 10)%"
        case let .error(error):
            return "error 💔 \(error.localizedDescription)"
        case .stopped:
            return "Stopped 🚫"
        case .synced:
            return "Synced 😎"
        case let .enhancing(progress):
            return "Enhancing 🤖 \(floor(progress.progress * 1000) / 10)%"
        case .fetching:
            return "Fetching UTXOs"
        case .unprepared:
            return "Unprepared"
        case .disconnected:
            return "Disconnected"
        }
    }
}
