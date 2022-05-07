//
//  Memo.swift
//  
//
//  Created by Pacu on 5/11/22.
//

import Foundation

public enum Memo: Equatable {
    case empty
    case text(MemoText)
    case future(MemoBytes)
    case arbitrary([UInt8])

    /// Parses the given bytes as in ZIP-302
    public init?(bytes: [UInt8]) throws {
        self = try MemoBytes(bytes: bytes).intoMemo()
    }

    /// Converts these memo bytes into a ZIP-302 Memo
    public init?(memoBytes: MemoBytes) throws {
        self = try memoBytes.intoMemo()
    }

    /// Creates a `.text(TextMemo)` Memo using the `UTF8View` of the given string
    /// - Throws:
    ///   - `MemoBytes.Errors.tooLong(length)` if the UTF-8 length
    /// of this string is greater than `MemoBytes.capacity`  (512 bytes)
    public init?(string: String) throws {
        self = .text(try MemoText(String(string.utf8)))
    }
}

public extension Memo {
    func asMemoBytes() throws -> MemoBytes {
        switch self {
        case .empty:
            return MemoBytes.empty()

        case .text(let textMemo):
            guard let bytes = textMemo.string.data(using: .utf8)?.bytes else {
                throw MemoBytes.Errors.invalidUTF8
            }

            return try MemoBytes(bytes: bytes)

        case .future(let memoBytes):
            return memoBytes

        case .arbitrary(var arbitraryBytes):
            arbitraryBytes.insert(0xFF, at: 0)
            return try MemoBytes(bytes:arbitraryBytes)
        }
    }
}

/// A wrapper on `String` so that `Memo` can't be created with an invalid String
public struct MemoText: Equatable {
    public private(set) var string: String

    init(_ string: String) throws {
        guard string.utf8.count <= MemoBytes.capacity else {
            throw MemoBytes.Errors.tooLong(string.utf8.count)
        }

        guard !string.containsCStringNullBytesBeforeStringEnding() else {
            throw MemoBytes.Errors.invalidUTF8
        }

        self.string = string
    }
}

public struct MemoBytes: Equatable {
    public enum Errors: Error {
        case invalidUTF8
        case tooLong(Int)
    }

    public static let capacity: Int = 512

    public private(set) var bytes: [UInt8]

    /// Copies the given bytes into the inner array if this struct in the context of ZIP-302
    /// and returns a `MemoBytes`  struct
    /// - Throws: `Errors.tooLong(bytes.count)` if the count is greater than
    /// 512 bytes.
    ///
    public init(bytes: [UInt8]) throws {
        guard bytes.count <= Self.capacity else { throw Errors.tooLong(bytes.count) }

        var rawBytes = [UInt8](repeating: 0x0, count: Self.capacity)

        // replacing range is quite slow an inefficient. Use bare metal impl
        _ = bytes.withUnsafeBufferPointer { ptr in
            memmove(&rawBytes[0], ptr.baseAddress, ptr.count)
        }

        self.bytes = rawBytes
    }

    public static func empty() -> Self {
        try! Self(bytes: .emptyMemoBytes)
    }
}

extension MemoBytes.Errors: LocalizedError {
    var localizedDescription: String {
        switch self {
        case .invalidUTF8:
            return "MemoBytes.Errors.invalidUTF8: Invalid UTF-8 byte found on memo bytes"
        case .tooLong(let length):
            return "MemoBytes.Errors.tooLong(\(length)): found more bytes than the 512 bytes a ZIP-302 memo is allowed to contain."
        }
    }
}

public extension MemoBytes {
    func intoMemo() throws -> Memo {
        switch self.bytes[0] {
        case 0xF6:
            return self.bytes.dropFirst().first(where: { $0 != 0 }) == nil ?
                Memo.empty :
                Memo.future(self)

        case 0xFF:
            return .arbitrary([UInt8](bytes[1...]))

        case 0x00 ... 0xF4:
            guard let validatedUTF8String = String(validatingUTF8: self.unpaddedRawBytes()) else {
                throw MemoBytes.Errors.invalidUTF8
            }

            return .text(try MemoText(validatedUTF8String))

        default:
            return .future(self)
        }
    }
}

extension MemoBytes {

    ///  Returns raw bytes, excluding null padding
    func unpaddedRawBytes() -> [UInt8] {
        guard let firstNullByte = self.bytes.enumerated()
            .reversed()
            .first(where: { $0.1 != 0 })
            .map({ $0.0 + 1 }) else { return [UInt8](bytes[0 ... 1]) }

        return [UInt8](bytes[0 ... firstNullByte])
    }
}

extension Array where Element == UInt8 {
    static var emptyMemoBytes: [UInt8] {
        var emptyMemo = [UInt8](repeating: 0x00, count: MemoBytes.capacity)
        emptyMemo[0] = 0xF6
        return emptyMemo
    }
}

extension String {
    public init?(validatingUTF8 cString: UnsafePointer<UInt8>) {
        guard let (s, _) = String.decodeCString(cString, as: UTF8.self,
                                                repairingInvalidCodeUnits: false) else {
            return nil
        }
        self = s
    }
}
