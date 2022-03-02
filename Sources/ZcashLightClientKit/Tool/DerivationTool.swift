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
    
    func isValidShieldedAddress(_ zAddress: String) throws -> Bool
}

public protocol KeyDeriving {
    /**
    Given a seed and a number of accounts, return the associated viewing keys.
     
    - Parameter seed: the seed from which to derive viewing keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
     
    - Returns: the viewing keys that correspond to the seed, formatted as Strings.
    */
    func deriveViewingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [String]

    /**
    Given a spending key, return the associated viewing key.
    
    - Parameter spendingKey: the key from which to derive the viewing key.
    
    - Returns: the viewing key that corresponds to the spending key.
    */
    func deriveViewingKey(spendingKey: String) throws -> String

    /**
    Given a seed and a number of accounts, return the associated spending keys.
    
    - Parameter seed: the seed from which to derive spending keys.
    - Parameter numberOfAccounts: the number of accounts to use. Multiple accounts are not fully
    supported so the default value of 1 is recommended.
    
    - Returns: the spending keys that correspond to the seed, formatted as Strings.
    */
    func deriveSpendingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [String]
    
    /**
    Given a seed and account index, return the associated address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    func deriveShieldedAddress(seed: [UInt8], accountIndex: Int) throws -> String
    
    /**
    Given a viewing key string, return the associated address.
     
    - Parameter viewingKey: the viewing key to use for deriving the address. The viewing key is tied to
        a specific account so no account index is required.
     
    - Returns: the address that corresponds to the viewing key.
    */
    func deriveShieldedAddress(viewingKey: String) throws -> String
    
    /**
    Derives a transparent address  from seedbytes, specifying account and index
    */
    func deriveTransparentAddress(seed: [UInt8], account: Int, index: Int) throws -> String
    
    /**
    Derives a SecretKey to spend transparent funds from a transparent secret key wif encoded
    */
    func deriveTransparentPrivateKey(seed: [UInt8], account: Int, index: Int) throws -> String
    
    /**
    Derives a transparent address from the given transparent Secret Key
    */
    func deriveTransparentAddressFromPrivateKey(_ tsk: String) throws -> String
    
    func deriveTransparentAddressFromPublicKey(_ pubkey: String) throws -> String
    
    /**
    derives unified viewing keys from seedbytes, specifying a number of accounts
    - Returns an array of unified viewing key tuples.
    */
    func deriveUnifiedViewingKeysFromSeed(_ seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedViewingKey]
    
    /**
    derives a Unified Address from a Unified Viewing Key
    */
    func deriveUnifiedAddressFromUnifiedViewingKey(_ uvk: UnifiedViewingKey) throws -> UnifiedAddress
}

public enum KeyDerivationErrors: Error {
    case derivationError(underlyingError: Error)
    case unableToDerive
    case invalidInput
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
    public func deriveViewingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [String] {
        guard numberOfAccounts > 0, let numberOfAccounts = Int32(exactly: numberOfAccounts) else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            guard let keys = try rustwelding.deriveExtendedFullViewingKeys(seed: seed, accounts: numberOfAccounts, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
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
    public func deriveViewingKey(spendingKey: String) throws -> String {
        do {
            guard let key = try rustwelding.deriveExtendedFullViewingKey(spendingKey, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return key
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
    public func deriveSpendingKeys(seed: [UInt8], numberOfAccounts: Int) throws -> [String] {
        guard numberOfAccounts > 0, let numberOfAccounts = Int32(exactly: numberOfAccounts) else {
            throw KeyDerivationErrors.invalidInput
        }
        do {
            guard let keys = try rustwelding.deriveExtendedSpendingKeys(seed: seed, accounts: numberOfAccounts, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return keys
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Given a seed and account index, return the associated address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    public func deriveShieldedAddress(seed: [UInt8], accountIndex: Int) throws -> String {
        guard accountIndex >= 0, let accountIndex = Int32(exactly: accountIndex) else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            guard let address = try rustwelding.deriveShieldedAddressFromSeed(seed: seed, accountIndex: accountIndex, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return address
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Given a viewing key string, return the associated address.
     
    - Parameter viewingKey: the viewing key to use for deriving the address. The viewing key is tied to
    a specific account so no account index is required.
     
    - Returns: the address that corresponds to the viewing key.
    */
    public func deriveShieldedAddress(viewingKey: String) throws -> String {
        do {
            guard let zaddr = try rustwelding.deriveShieldedAddressFromViewingKey(viewingKey, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return zaddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func deriveTransparentAddress(seed: [UInt8], account: Int = 0, index: Int = 0) throws -> String {
        do {
            guard let zaddr = try rustwelding.deriveTransparentAddressFromSeed(
                seed: seed,
                account: account,
                index: index,
                networkType: networkType
            ) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return zaddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func deriveUnifiedViewingKeysFromSeed(_ seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedViewingKey] {
        guard numberOfAccounts > 0 else {
            throw KeyDerivationErrors.invalidInput
        }
        do {
            return try rustwelding.deriveUnifiedViewingKeyFromSeed(seed, numberOfAccounts: numberOfAccounts, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    derives a Unified Address from a Unified Viewing Key
    */
    public func deriveUnifiedAddressFromUnifiedViewingKey(_ uvk: UnifiedViewingKey) throws -> UnifiedAddress {
        do {
            let tAddress = try deriveTransparentAddressFromPublicKey(uvk.extpub)
            let zAddress = try deriveShieldedAddress(viewingKey: uvk.extfvk)
            return ConcreteUnifiedAddress(tAddress: tAddress, zAddress: zAddress)
        } catch {
            throw KeyDerivationErrors.unableToDerive
        }
    }
    
    public func deriveTransparentAddressFromPublicKey(_ pubkey: String) throws -> String {
        guard !pubkey.isEmpty else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            return try rustwelding.derivedTransparentAddressFromPublicKey(pubkey, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Derives the transparent funds private key from the given seed
    - Throws:
    -  KeyDerivationErrors.derivationError with the underlying error when it fails
    - KeyDerivationErrors.unableToDerive when there's an unknown error
    */
    public func deriveTransparentPrivateKey(seed: [UInt8], account: Int = 0, index: Int = 0) throws -> String {
        do {
            guard let seedKey = try rustwelding.deriveTransparentPrivateKeyFromSeed(
                seed: seed,
                account: account,
                index: index,
                networkType: networkType
            ) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return seedKey
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}

extension DerivationTool: KeyValidation {
    public func isValidExtendedViewingKey(_ extvk: String) throws -> Bool {
        do {
            return try rustwelding.isValidExtendedFullViewingKey(extvk, networkType: networkType)
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
    
    public func isValidShieldedAddress(_ zAddress: String) throws -> Bool {
        do {
            return try rustwelding.isValidShieldedAddress(zAddress, networkType: networkType)
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    /**
    Derives the transparent address from a WIF Private Key
    - Throws:
        - KeyDerivationErrors.derivationError with the underlying error when it fails
        - KeyDerivationErrors.unableToDerive when there's an unknown error
    */
    public func deriveTransparentAddressFromPrivateKey(_ tsk: String) throws -> String {
        do {
            guard let tAddr = try rustwelding.deriveTransparentAddressFromSecretKey(tsk, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return tAddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}

private struct ConcreteUnifiedAddress: UnifiedAddress {
    var tAddress: TransparentAddress
    var zAddress: SaplingShieldedAddress
}
