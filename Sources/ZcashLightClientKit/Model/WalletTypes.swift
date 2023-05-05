//
//  WalletTypes.swift
//
//
//  Created by Francisco Gindre on 4/6/21.
//

/// Something that can be encoded as a String
public protocol StringEncoded {
    var stringEncoded: String { get }
}

public struct UnifiedSpendingKey: Equatable, Undescribable {
    let network: NetworkType
    let bytes: [UInt8]
    public let account: UInt32
}

/// Sapling Extended Spending Key
public struct SaplingExtendedSpendingKey: Equatable, StringEncoded, Undescribable {
    let encoding: String

    public var stringEncoded: String {
        encoding
    }

    /// Initializes a new Sapling Extended Full Viewing Key from the provided string encoding
    /// - Parameters:
    ///  - parameter encoding: String encoding of ExtSK
    ///  - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    /// - Throws: `spendingKeyInvalidInput`when the provided encoding is found to be invalid
    public init(encoding: String, network: NetworkType) throws {
        guard DerivationTool(networkType: network).isValidSaplingExtendedSpendingKey(encoding) else {
            throw ZcashError.spendingKeyInvalidInput
        }
        self.encoding = encoding
    }
}

/// A Transparent Account Private Key
public struct TransparentAccountPrivKey: Equatable, Undescribable {
    let encoding: String
}

/// A ZIP 316 Unified Full Viewing Key.
public struct UnifiedFullViewingKey: Equatable, StringEncoded, Undescribable {
    let encoding: String
    public let account: UInt32

    public var stringEncoded: String { encoding }

    /// Initializes a new UnifiedFullViewingKey (UFVK) from the provided string encoding
    /// - Parameters:
    ///  - parameter encoding: String encoding of unified full viewing key
    ///  - parameter account: account number of the given UFVK
    ///  - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    /// - Throws: `unifiedFullViewingKeyInvalidInput`when the provided encoding is found to be invalid
    public init(encoding: String, account: UInt32, network: NetworkType) throws {
        guard DerivationTool(networkType: network).isValidUnifiedFullViewingKey(encoding) else {
            throw ZcashError.unifiedFullViewingKeyInvalidInput
        }

        self.encoding = encoding
        self.account = account
    }
}

public struct SaplingExtendedFullViewingKey: Equatable, StringEncoded, Undescribable {
    let encoding: String
    public var stringEncoded: String {
        encoding
    }

    /// Initializes a new Extended Full Viewing key (EFVK) for Sapling from the provided string encoding
    /// - Parameters:
    ///  - parameter encoding: String encoding of Sapling extended full viewing key
    ///  - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    /// - Throws: `extetendedFullViewingKeyInvalidInput`when the provided encoding is found to be invalid
    public init(encoding: String, network: NetworkType) throws {
        guard ZcashKeyDerivationBackend(networkType: network).isValidSaplingExtendedFullViewingKey(encoding) else {
            throw ZcashError.extetendedFullViewingKeyInvalidInput
        }
        self.encoding = encoding
    }
}

public enum AddressType: Equatable {
    case p2pkh
    case p2sh
    case sapling
    case unified
    
    var id: UInt32 {
        switch self {
        case .p2pkh:  return 0
        case .p2sh:  return 1
        case .sapling: return 2
        case .unified: return 3
        }
    }
}

extension AddressType {
    static func forId(_ id: UInt32) -> AddressType? {
        switch id {
        case 0: return .p2pkh
        case 1: return .p2sh
        case 2: return .sapling
        case 3: return .unified
        default: return nil
        }
    }
}

/// A Transparent Address that can be encoded as a String
///
/// Transactions sent to this address are totally visible in the public
/// ledger. See "Multiple transaction types" in https://z.cash/technology/
public struct TransparentAddress: Equatable, StringEncoded, Comparable {
    let encoding: String

    public var stringEncoded: String { encoding }

    /// Initializes a new TransparentAddress (t-address) from the provided string encoding
    ///
    ///  - parameter encoding: String encoding of the t-address
    ///  - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    /// - Throws: `transparentAddressInvalidInput`when the provided encoding is found to be invalid
    public init(encoding: String, network: NetworkType) throws {
        guard DerivationTool(networkType: network).isValidTransparentAddress(encoding) else {
            throw ZcashError.transparentAddressInvalidInput
        }

        self.encoding = encoding
    }

    public static func < (lhs: TransparentAddress, rhs: TransparentAddress) -> Bool {
        return lhs.encoding < rhs.encoding
    }
}

/// Represents a Sapling receiver address. Comonly called zAddress.
/// This address corresponds to the Zcash Sapling shielded pool.
/// Although this it is fully functional, we encourage developers to
/// choose `UnifiedAddress` before Sapling or Transparent ones.
public struct SaplingAddress: Equatable, StringEncoded {
    let encoding: String

    public var stringEncoded: String { encoding }

    /// Initializes a new Sapling shielded address (z-address) from the provided string encoding
    ///
    /// - parameter encoding: String encoding of the z-address
    /// - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    ///
    /// - Throws: `saplingAddressInvalidInput` when the provided encoding is found to be invalid
    public init(encoding: String, network: NetworkType) throws {
        guard DerivationTool(networkType: network).isValidSaplingAddress(encoding) else {
            throw ZcashError.saplingAddressInvalidInput
        }

        self.encoding = encoding
    }
}

public struct UnifiedAddress: Equatable, StringEncoded {
    let networkType: NetworkType

    public enum ReceiverTypecodes: Hashable {
        case p2pkh
        case p2sh
        case sapling
        case orchard
        case unknown(UInt32)

        init(typecode: UInt32) {
            switch typecode {
            case 0x00:
                self = .p2pkh
            case 0x01:
                self = .p2sh
            case 0x02:
                self = .sapling
            case 0x03:
                self = .orchard
            default:
                self = .unknown(typecode)
            }
        }
    }

    let encoding: String

    public var stringEncoded: String { encoding }

    /// Initializes a new Unified Address (UA) from the provided string encoding
    /// - Parameters:
    ///  - parameter encoding: String encoding of the UA
    ///  - parameter network: `NetworkType` corresponding to the encoding (Mainnet or Testnet)
    /// - Throws: `unifiedAddressInvalidInput` when the provided encoding is found to be invalid
    public init(encoding: String, network: NetworkType) throws {
        networkType = network
        guard DerivationTool(networkType: network).isValidUnifiedAddress(encoding) else {
            throw ZcashError.unifiedAddressInvalidInput
        }

        self.encoding = encoding
    }

    /// returns an array of `UnifiedAddress.ReceiverTypecodes` ordered by precedence
    public func availableReceiverTypecodes() throws -> [UnifiedAddress.ReceiverTypecodes] {
        return try DerivationTool(networkType: networkType).receiverTypecodesFromUnifiedAddress(self)
    }
}

public enum TransactionRecipient: Equatable {
    case address(Recipient)
    case internalAccount(UInt32)
}

/// Represents a valid recipient of Zcash
public enum Recipient: Equatable, StringEncoded {
    case transparent(TransparentAddress)
    case sapling(SaplingAddress)
    case unified(UnifiedAddress)

    public var stringEncoded: String {
        switch self {
        case .transparent(let tAddr):
            return tAddr.stringEncoded
        case .sapling(let zAddr):
            return zAddr.stringEncoded
        case .unified(let uAddr):
            return uAddr.stringEncoded
        }
    }

    /// Initializes a `Recipient` with string encoded Zcash address
    /// - Parameter string: a string encoded Zcash address
    /// - Parameter network: the `ZcashNetwork.NetworkType` of the recipient
    /// - Throws: `recipientInvalidInput` if the received string-encoded address can't be initialized as a valid Zcash Address.
    public init(_ string: String, network: NetworkType) throws {
        if let unified = try? UnifiedAddress(encoding: string, network: network) {
            self = .unified(unified)
        } else if let sapling = try? SaplingAddress(encoding: string, network: network) {
            self = .sapling(sapling)
        } else if let transparent = try? TransparentAddress(encoding: string, network: network) {
            self = .transparent(transparent)
        } else {
            throw ZcashError.recipientInvalidInput
        }
    }
    
    static func forEncodedAddress(encoded: String) -> (Recipient, NetworkType)? {
        return DerivationTool.getAddressMetadata(encoded).map { metadata in
            switch metadata.addressType {
            case .p2pkh: return (.transparent(TransparentAddress(validatedEncoding: encoded)),
                metadata.networkType)
            case .p2sh:  return (.transparent(TransparentAddress(validatedEncoding: encoded)), metadata.networkType)
            case .sapling: return (.sapling(SaplingAddress(validatedEncoding: encoded)), metadata.networkType)
            case .unified: return (.unified(UnifiedAddress(validatedEncoding: encoded, networkType: metadata.networkType)), metadata.networkType)
            }
        }
    }
}

public struct WalletBalance: Equatable {
    public let verified: Zatoshi
    public let total: Zatoshi
    
    public init(verified: Zatoshi, total: Zatoshi) {
        self.verified = verified
        self.total = total
    }
}

public extension WalletBalance {
    static var zero: WalletBalance {
        Self(verified: .zero, total: .zero)
    }
}
