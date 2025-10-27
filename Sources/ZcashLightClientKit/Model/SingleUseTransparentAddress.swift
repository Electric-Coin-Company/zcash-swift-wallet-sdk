//
//  SingleUseTransparentAddress.swift
//  ZcashLightClientKit
//
//  Created by Lukáš Korba on 2025-10-27.
//

import Foundation

public struct SingleUseTransparentAddress: Equatable {
    let address: String
    let gapPosition: UInt32
    let gapLimit: UInt32
}

public enum SingleUseTransparentResult: Equatable {
    case notFound
    case found(String)
//    init(from ffi: UnsafeMutablePointer<FfiAddressCheckResult>) {
//        switch ffi.tag {
//        case .notFound:
//            self = .notFound
//            
//        case .found:
//            let address = ffi.found.address.map { String(cString: $0) } ?? ""
//            self = .found(address: address)
//        }
//    }
}

/*
typedef struct FfiSingleUseTaddr {
  char *address;
  uint32_t gap_position;
  uint32_t gap_limit;
} FfiSingleUseTaddr;


/**
 * The result of checking for UTXOs received by an ephemeral address.
 *
 */
enum FfiAddressCheckResult_Tag {
  /**
   * No UTXOs were found as a result of the check.
   */
  FfiAddressCheckResult_NotFound,
  /**
   * UTXOs were found for the given address.
   */
  FfiAddressCheckResult_Found,
};
typedef uint8_t FfiAddressCheckResult_Tag;

typedef struct FfiAddressCheckResult_Found_Body {
  char *address;
} FfiAddressCheckResult_Found_Body;

typedef struct FfiAddressCheckResult {
  FfiAddressCheckResult_Tag tag;
  union {
    FfiAddressCheckResult_Found_Body found;
  };
} FfiAddressCheckResult;
*/
