//
//  ValidateServerAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

final class ValidateServerAction {
    let configProvider: CompactBlockProcessor.ConfigProvider
    let rustBackend: ZcashRustBackendWelding
    var service: LightWalletService

    init(container: DIContainer, configProvider: CompactBlockProcessor.ConfigProvider) {
        self.configProvider = configProvider
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        service = container.resolve(LightWalletService.self)
    }
}

extension ValidateServerAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        let config = await configProvider.config
        // ServiceMode to resolve
        // called each sync, an action in a state machine diagram
        // https://github.com/Electric-Coin-Company/zcash-swift-wallet-sdk/blob/main/docs/images/cbp_state_machine.png
        // TODO: [#1571] connection enforeced to .direct for the next SDK release
        // https://github.com/Electric-Coin-Company/zcash-swift-wallet-sdk/issues/1571
//        let info = try await service.getInfo(mode: .defaultTor)
        let info = try await service.getInfo(mode: .direct)
        let localNetwork = config.network
        let saplingActivation = config.saplingActivation

        // check network types
        guard let remoteNetworkType = NetworkType.forChainName(info.chainName) else {
            throw ZcashError.compactBlockProcessorChainName(info.chainName)
        }

        guard remoteNetworkType == localNetwork.networkType else {
            throw ZcashError.compactBlockProcessorNetworkMismatch(localNetwork.networkType, remoteNetworkType)
        }

        guard saplingActivation == info.saplingActivationHeight else {
            throw ZcashError.compactBlockProcessorSaplingActivationMismatch(saplingActivation, BlockHeight(info.saplingActivationHeight))
        }

        // check branch id
        let localBranch = try rustBackend.consensusBranchIdFor(height: Int32(info.blockHeight))

        guard let remoteBranchID = ConsensusBranchID.fromString(info.consensusBranchID) else {
            throw ZcashError.compactBlockProcessorConsensusBranchID
        }

        guard remoteBranchID == localBranch else {
            throw ZcashError.compactBlockProcessorWrongConsensusBranchId(localBranch, remoteBranchID)
        }

        await context.update(state: .fetchUTXO)
        return context
    }

    func stop() async { }
}
