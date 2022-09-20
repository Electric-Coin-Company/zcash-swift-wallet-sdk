//
//  DerivationTool.swift
//  Pods
//
//  Created by Francisco Gindre on 10/8/20.
//

import Foundation

public protocol KeyValidation {
    func isValidExtendedViewingKey(_ extvk: String) throws -> Bool
    
    func isValidTransparentAddress(_ tAddress: String) throws -> Bool
    
    func isValidSaplingAddress(_ zAddress: String) throws -> Bool

    func isValidSaplingExtendedSpendingKey(_ extsk: String) throws -> Bool

    func isValidUnifiedAddress(_ unifiedAddress: String) throws -> Bool
}

public protocol KeyDeriving {
    /**
    Given a seed and a number of accounts, return the associated viewing keys.
     
    - Parameter seed: the seed from which to derive viewing keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
     
    - Returns: the viewing keys that correspond to the seed, formatted as Strings.
    */
    func deriveUnifiedFullViewingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedFullViewingKey]

    /**
    Given a spending key, return the associated viewing key.
    
    - Parameter spendingKey: the key from which to derive the viewing key.
    
    - Returns: the viewing key that corresponds to the spending key.
    */
    func deriveViewingKey(spendingKey: SaplingExtendedSpendingKey) throws -> SaplingExtendedFullViewingKey

    /**
    Given a seed and a number of accounts, return the associated spending keys.
    
    - Parameter seed: the seed from which to derive spending keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
    
    - Returns: the spending keys that correspond to the seed, formatted as Strings.
    */
    func deriveSpendingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [SaplingExtendedSpendingKey]
    
    /**
    Given a seed and account index, return the associated unified address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    func deriveUnifiedAddress(seed: [UInt8], accountIndex: Int) throws -> UnifiedAddress
    

    /// Given a unified full viewing key string, return the associated unified address.
    ///
    /// - Parameter ufvk: the viewing key to use for deriving the address. The viewing key is tied to
    ///     a specific account so no account index is required.
    ///
    /// - Returns: the address that corresponds to the viewing key.
    func deriveUnifiedAddress(from ufvk: UnifiedFullViewingKey) throws -> UnifiedAddress
    
    /**
    Derives a transparent address  from seedbytes, specifying account and index
    */
    func deriveTransparentAddress(seed: [UInt8], account: Int, index: Int) throws -> TransparentAddress
    
    /**
    Derives the account private key to spend transparent funds from a specific seed and account
    */
    func deriveTransparentAccountPrivateKey(seed: [UInt8], account: Int) throws -> TransparentAccountPrivKey
    
    /**
    Derives a transparent address from the given transparent account private key
    */
    func deriveTransparentAddressFromAccountPrivateKey(_ xprv: TransparentAccountPrivKey, index: Int) throws -> TransparentAddress

    /// Extracts the `UnifiedAddress.ReceiverTypecodes` from the given `UnifiedAddress`
    /// - Parameter address: the `UnifiedAddress`
    /// - Throws
    func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes]
}

public enum KeyDerivationErrors: Error {
    case derivationError(underlyingError: Error)
    case unableToDerive
    case invalidInput
    case invalidUnifiedAddress
}

public class DerivationTool: KeyDeriving {
    var rustwelding: ZcashRustBackendWelding.Type = ZcashRustBackend.self
    
    var networkType: NetworkType
    
    public init(networkType: NetworkType) {
        self.networkType = networkType
    }

    /**
    Given a seed and a number of accounts, return the associated viewing keys.
     
    - Parameter seed: the seed from which to derive viewing keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
     
    - Returns: the viewing keys that correspond to the seed, formatted as Strings.
    */
    public func deriveUnifiedFullViewingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedFullViewingKey] {
        guard numberOfAccounts > 0, let numberOfAccounts = Int32(exactly: numberOfAccounts) else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            let ufvks = try rustwelding.deriveUnifiedFullViewingKeyFromSeed(seed, numberOfAccounts: numberOfAccounts, networkType: networkType)

            var keys: [UnifiedFullViewingKey] = []
            for ufvk in ufvks {
                keys.append(ufvk)
            }
            return keys
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    /**
    Given a spending key, return the associated viewing key.
    
    - Parameter spendingKey: the key from which to derive the viewing key.
    
    - Returns: the viewing key that corresponds to the spending key.
    */
    public func deriveViewingKey(spendingKey: SaplingExtendedSpendingKey) throws -> SaplingExtendedFullViewingKey {
        do {
            guard let key = try rustwelding.deriveSaplingExtendedFullViewingKey(spendingKey, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return key
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func deriveUnifiedFullViewingKeysFromSeed(_ seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedFullViewingKey] {
        guard numberOfAccounts > 0, let numberOfAccounts = Int32(exactly: numberOfAccounts) else {
            throw KeyDerivationErrors.invalidInput
        }
        do {
            return try rustwelding.deriveUnifiedFullViewingKeyFromSeed(seed, numberOfAccounts: numberOfAccounts, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Given a seed and a number of accounts, return the associated spending keys.
    
    - Parameter seed: the seed from which to derive spending keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
    
    - Returns: the spending keys that correspond to the seed, formatted as Strings.
    */
    public func deriveSpendingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [SaplingExtendedSpendingKey] {
        guard numberOfAccounts > 0, let numberOfAccounts = Int32(exactly: numberOfAccounts) else {
            throw KeyDerivationErrors.invalidInput
        }
        do {
            guard let keys = try rustwelding.deriveSaplingExtendedSpendingKeys(seed: seed, accounts: numberOfAccounts, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return keys
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Given a seed and account index, return the associated unified address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    public func deriveUnifiedAddress(seed: [UInt8], accountIndex: Int) throws -> UnifiedAddress {
        guard accountIndex >= 0, let accountIndex = Int32(exactly: accountIndex) else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            guard let address = try rustwelding.deriveUnifiedAddressFromSeed(seed: seed, accountIndex: accountIndex, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return UnifiedAddress(validatedEncoding: address, network: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Given a unified viewing key string, return the associated unified address.
     
    - Parameter viewingKey: the viewing key to use for deriving the address. The viewing key is tied to
    a specific account so no account index is required.
     
    - Returns: the address that corresponds to the viewing key.
    */
    public func deriveUnifiedAddress(from ufvk: UnifiedFullViewingKey) throws -> UnifiedAddress {
        do {
            guard let stringEncodedUA = try rustwelding.deriveUnifiedAddressFromViewingKey(ufvk.stringEncoded, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return UnifiedAddress(validatedEncoding: stringEncodedUA, network: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func receiverTypecodesFromUnifiedAddress(_ address: UnifiedAddress) throws -> [UnifiedAddress.ReceiverTypecodes] {
        do {
            return try rustwelding.receiverTypecodesOnUnifiedAddress(address.stringEncoded)
                .map({ UnifiedAddress.ReceiverTypecodes(typecode: $0) })
        } catch {
            throw KeyDerivationErrors.invalidUnifiedAddress
        }
    }
    
    public func deriveTransparentAddress(seed: [UInt8], account: Int = 0, index: Int = 0) throws -> TransparentAddress {
        do {
            guard let taddr = try rustwelding.deriveTransparentAddressFromSeed(
                seed: seed,
                account: account,
                index: index,
                networkType: networkType
            ) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return TransparentAddress(validatedEncoding: taddr)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    

    /// derives a Unified Address from a Unified Full Viewing Key
    public func deriveUnifiedAddressFromUnifiedFullViewingKey(_ ufvk: UnifiedFullViewingKey) throws -> UnifiedAddress {
        do {
            return try deriveUnifiedAddress(from: ufvk)
        } catch {
            throw KeyDerivationErrors.unableToDerive
        }
    }

    /// Derives the transparent funds account private key from the given seed
    /// - Throws:
    /// -  KeyDerivationErrors.derivationError with the underlying error when it fails
    /// - KeyDerivationErrors.unableToDerive when there's an unknown error
    public func deriveTransparentAccountPrivateKey(seed: [UInt8], account: Int = 0) throws -> TransparentAccountPrivKey {
        do {
            guard let seedKey = try rustwelding.deriveTransparentAccountPrivateKeyFromSeed(
                seed: seed,
                account: account,
                networkType: networkType
            ) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return TransparentAccountPrivKey(encoding: seedKey)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }


    /// Derives the transparent address from an account private key
    /// - Throws:
    ///     - KeyDerivationErrors.derivationError with the underlying error when it fails
    ///     - KeyDerivationErrors.unableToDerive when there's an unknown error
    public func deriveTransparentAddressFromAccountPrivateKey(_ xprv: TransparentAccountPrivKey, index: Int) throws -> TransparentAddress {
        do {
            guard let tAddr = try rustwelding.deriveTransparentAddressFromAccountPrivateKey(xprv.encoding, index: index, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return TransparentAddress(validatedEncoding: tAddr)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}

extension DerivationTool: KeyValidation {
    public func isValidUnifiedAddress(_ unifiedAddress: String) throws -> Bool {
        do {
            return try rustwelding.isValidUnifiedAddress(unifiedAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func isValidExtendedViewingKey(_ extvk: String) throws -> Bool {
        do {
            return try rustwelding.isValidSaplingExtendedFullViewingKey(extvk, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func isValidTransparentAddress(_ tAddress: String) throws -> Bool {
        do {
            return try rustwelding.isValidTransparentAddress(tAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func isValidSaplingAddress(_ zAddress: String) throws -> Bool {
        do {
            return try rustwelding.isValidSaplingAddress(zAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }

    public func isValidSaplingExtendedSpendingKey(_ extsk: String) throws -> Bool {
        do {
            return try rustwelding.isValidSaplingExtendedSpendingKey(extsk, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}


extension TransparentAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}

extension SaplingAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
 }

extension UnifiedAddress {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this..
    init(validatedEncoding: String, network: NetworkType) {
        self.encoding = validatedEncoding
        self.network = network
    }
}

extension UnifiedFullViewingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String, account: UInt32) {
        self.encoding = validatedEncoding
        self.account = account
    }
}


extension SaplingExtendedFullViewingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}


extension SaplingExtendedSpendingKey {
    /// This constructor is for internal use for Strings encodings that are assumed to be
    /// already validated by another function. only for internal use. Unless you are
    /// constructing an address from a primitive function of the FFI, you probably
    /// shouldn't be using this.
    init(validatedEncoding: String) {
        self.encoding = validatedEncoding
    }
}
