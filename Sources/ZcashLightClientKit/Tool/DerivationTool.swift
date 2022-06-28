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
    Given a seed and account index, return the associated unified address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    func deriveUnifiedAddress(seed: [UInt8], accountIndex: Int) throws -> String
    
    /**
    Given a unified viewing key string, return the associated unified address.
     
    - Parameter viewingKey: the viewing key to use for deriving the address. The viewing key is tied to
        a specific account so no account index is required.
     
    - Returns: the address that corresponds to the viewing key.
    */
    func deriveUnifiedAddress(viewingKey: String) throws -> String
    
    /**
    Derives a transparent address  from seedbytes, specifying account and index
    */
    func deriveTransparentAddress(seed: [UInt8], account: Int, index: Int) throws -> String
    
    /**
    Derives the account private key to spend transparent funds from a specific seed and account
    */
    func deriveTransparentAccountPrivateKey(seed: [UInt8], account: Int) throws -> String
    
    /**
    Derives a transparent address from the given transparent account private key
    */
    func deriveTransparentAddressFromAccountPrivateKey(_ xprv: String, index: Int) throws -> String
    
    func deriveTransparentAddressFromPublicKey(_ pubkey: String) throws -> String
    
    /**
    derives unified full viewing keys from seedbytes, specifying a number of accounts
    - Returns an array of unified viewing key tuples.
    */
    func deriveUnifiedFullViewingKeysFromSeed(_ seed: [UInt8], numberOfAccounts: Int) throws -> [UnifiedFullViewingKey]
    
    /**
    derives a Unified Address from a Unified Full Viewing Key
    */
    func deriveUnifiedAddressFromUnifiedFullViewingKey(_ ufvk: UnifiedFullViewingKey) throws -> UnifiedAddress
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
            let ufvks = try rustwelding.deriveUnifiedFullViewingKeyFromSeed(seed, numberOfAccounts: numberOfAccounts, networkType: networkType)

            var keys: [String] = []
            for ufvk in ufvks {
                keys.append(ufvk.encoding)
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
    Given a seed and account index, return the associated unified address.
     
    - Parameter seed: the seed from which to derive the address.
    - Parameter accountIndex: the index of the account to use for deriving the address. Multiple
    accounts are not fully supported so the default value of 1 is recommended.
     
    - Returns: the address that corresponds to the seed and account index.
    */
    public func deriveUnifiedAddress(seed: [UInt8], accountIndex: Int) throws -> String {
        guard accountIndex >= 0, let accountIndex = Int32(exactly: accountIndex) else {
            throw KeyDerivationErrors.invalidInput
        }
        
        do {
            guard let address = try rustwelding.deriveUnifiedAddressFromSeed(seed: seed, accountIndex: accountIndex, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return address
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
    public func deriveUnifiedAddress(viewingKey: String) throws -> String {
        do {
            guard let zaddr = try rustwelding.deriveUnifiedAddressFromViewingKey(viewingKey, networkType: networkType) else {
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
    derives a Unified Address from a Unified Full Viewing Key
    */
    public func deriveUnifiedAddressFromUnifiedFullViewingKey(_ ufvk: UnifiedFullViewingKey) throws -> UnifiedAddress {
        do {
            let encoding = try deriveUnifiedAddress(viewingKey: ufvk.encoding)
            return ConcreteUnifiedAddress(encoding: encoding)
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
    Derives the transparent funds account private key from the given seed
    - Throws:
    -  KeyDerivationErrors.derivationError with the underlying error when it fails
    - KeyDerivationErrors.unableToDerive when there's an unknown error
    */
    public func deriveTransparentAccountPrivateKey(seed: [UInt8], account: Int = 0) throws -> String {
        do {
            guard let seedKey = try rustwelding.deriveTransparentAccountPrivateKeyFromSeed(
                seed: seed,
                account: account,
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
    Derives the transparent address from an account private key
    - Throws:
        - KeyDerivationErrors.derivationError with the underlying error when it fails
        - KeyDerivationErrors.unableToDerive when there's an unknown error
    */
    public func deriveTransparentAddressFromAccountPrivateKey(_ xprv: String, index: Int) throws -> String {
        do {
            guard let tAddr = try rustwelding.deriveTransparentAddressFromAccountPrivateKey(xprv, index: index, networkType: networkType) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return tAddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
}

private struct ConcreteUnifiedAddress: UnifiedAddress {
    var encoding: String
}
