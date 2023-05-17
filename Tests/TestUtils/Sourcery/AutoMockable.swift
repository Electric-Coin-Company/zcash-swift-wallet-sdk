//
//  AutoMockable.swift
//
//
//  Created by Michal Fousek on 04.04.2023.
//

/// This file defines types for which we need to generate mocks for usage in Player tests.
/// Each type must appear in appropriate section according to which module it comes from.

// sourcery:begin: AutoMockable

@testable import ZcashLightClientKit

extension ZcashRustBackendWelding { }
extension Synchronizer { }
extension LightWalletService { }
extension LightWalletdInfo { }

// sourcery:end:
