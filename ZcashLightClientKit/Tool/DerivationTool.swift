//
//  DerivationTool.swift
//  Pods
//
//  Created by Francisco Gindre on 10/8/20.
//

import Foundation

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
    // WIP probably shouldn't be used just yet. Why?
            //  - because we need the private key associated with this seed and this function doesn't return it.
            //  - the underlying implementation needs to be split out into a few lower-level calls
    func deriveTransparentAddress(seed: [UInt8]) throws -> String
    
    func validateViewingKey(viewingKey: String) throws
}

public enum KeyDerivationErrors: Error {
    case derivationError(underlyingError: Error)
    case unableToDerive
    case invalidInput
}

public class DerivationTool: KeyDeriving {
    
    var rustwelding: ZcashRustBackendWelding.Type = ZcashRustBackend.self
    
    public static let `default` = DerivationTool()
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
            guard let keys = try rustwelding.deriveExtendedFullViewingKeys(seed: seed, accounts: numberOfAccounts) else {
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
            guard let key = try rustwelding.deriveExtendedFullViewingKey(spendingKey) else {
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
            guard let keys = try rustwelding.deriveExtendedSpendingKeys(seed: seed, accounts: numberOfAccounts) else {
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
            guard let address = try rustwelding.deriveShieldedAddressFromSeed(seed: seed, accountIndex: accountIndex) else {
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
            guard let zaddr = try rustwelding.deriveShieldedAddressFromViewingKey(viewingKey) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return zaddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    // WIP probably shouldn't be used just yet. Why?
            //  - because we need the private key associated with this seed and this function doesn't return it.
            //  - the underlying implementation needs to be split out into a few lower-level calls
    public func deriveTransparentAddress(seed: [UInt8]) throws -> String {
        do {
            guard let zaddr = try rustwelding.deriveTransparentAddressFromSeed(seed: seed) else {
                throw KeyDerivationErrors.unableToDerive
            }
            return zaddr
        } catch {
            throw KeyDerivationErrors.derivationError(underlyingError: error)
        }
    }
    
    public func validateViewingKey(viewingKey: String) throws {
                // TODO
    }
    
}
