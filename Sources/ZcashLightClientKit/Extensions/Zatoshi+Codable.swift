//
//  Zatoshi+Codable.swift
//  
//
//  Created by Francisco Gindre on 6/20/22.
//

import Foundation
/// This extension is needed to support SQLite Swift Codable Types
extension Zatoshi: Codable {
    enum CodingError: Error {
        case encodingError(String)
    }
    /// This codable implementation responds to limitaitons that SQLite Swift explains
    /// on its documentation https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#codable-types
    /// SQLite Sqift will encode custom types into a string and stores it in a single column. They do so by
    /// leveraging the Codable interface so this has to abide by them and their choice.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let amount = Int64(value) else {
            throw CodingError.encodingError("Decoding Error")
        }

        self.amount = amount
    }

    /// This codable implementation responds to limitaitons that SQLite Swift explains
    /// on its documentation https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#codable-types
    /// SQLite Sqift will encode custom types into a string and stores it in a single column. They do so by
    /// leveraging the Codable interface so this has to abide by them and their choice.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(String(self.amount))
    }
}
