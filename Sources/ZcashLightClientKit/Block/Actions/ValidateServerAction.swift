//
//  ValidateServerAction.swift
//  
//
//  Created by Michal Fousek on 05.05.2023.
//

import Foundation

class ValidateServerAction {
    let config: CompactBlockProcessorNG.Configuration
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService

    init(container: DIContainer, config: CompactBlockProcessorNG.Configuration) {
        self.config = config
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        service = container.resolve(LightWalletService.self)
    }
}

extension ValidateServerAction: Action {
    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProgress) async -> Void) async throws -> ActionContext {
        let info = try await service.getInfo()
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

        await context.update(state: .computeSyncRanges)
        return context
    }

    func stop() async { }
}
