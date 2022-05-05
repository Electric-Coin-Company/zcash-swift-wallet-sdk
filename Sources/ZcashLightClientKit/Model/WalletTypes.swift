//
//  WalletTypes.swift
//  Pods
//
//  Created by Francisco Gindre on 4/6/21.
//

/**
Represents the wallet's birthday which can be thought of as a checkpoint at the earliest moment in history where
transactions related to this wallet could exist. Ideally, this would correspond to the latest block height at the
time the wallet key was created. Worst case, the height of Sapling activation could be used (280000).
 
Knowing a wallet's birthday can significantly reduce the amount of data that it needs to download because none of
the data before that height needs to be scanned for transactions. However, we do need the Sapling tree data in
order to construct valid transactions from that point forward. This birthday contains that tree data, allowing us
to avoid downloading all the compact blocks required in order to generate it.
 
New wallets can ignore any blocks created before their birthday.
 
- Parameters:
    - height: the height at the time the wallet was born
    -  hash: the block hash corresponding to the given height
    -  time: the time the wallet was born, in seconds
    -  tree: the sapling tree corresponding to the given height. This takes around 15 minutes of processing to
generate from scratch because all blocks since activation need to be considered. So when it is calculated in
advance it can save the user a lot of time.
*/
public struct WalletBirthday: Equatable {
    public private(set) var height: BlockHeight = -1
    public private(set) var hash: String = ""
    public private(set) var time: UInt32 = 0
    public private(set) var tree: String = ""
}


extension WalletBirthday: Decodable {
  //  let height: BlockHeight
  //  let hash: String
  //  let time: UInt32
  //  let tree: String
  //
  //  func walletBirthday() -> WalletBirthday {
  //    WalletBirthday(
  //      height: height,
  //      hash: hash,
  //      time: time,
  //      tree: tree
  //    )
  //  }

  public enum CodingKeys: String, CodingKey {
    case height
    case hash
    case time
    case tree
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.height = try Self.getHeight(from: container)
    self.hash = try container.decode(String.self, forKey: .hash)
    self.time = try container.decode(UInt32.self, forKey: .time)
    self.tree = try container.decode(String.self, forKey: .tree)
  }

  static func getHeight(from container: KeyedDecodingContainer<CodingKeys>) throws -> Int {
    guard
      let heightString = try? container.decode(String.self, forKey: .height),
      let height = Int(heightString)
    else {
      throw DecodingError.typeMismatch(
        String.self,
        DecodingError.Context(
          codingPath: [CodingKeys.height],
          debugDescription: "expected height to be encoded as a string",
          underlyingError: nil
        )
      )
    }
    return height
  }
}


/**
Groups a Sapling Extended Full Viewing Key an a tranparent address extended public key.
*/

public typealias ExtendedFullViewingKey = String
public typealias ExtendedPublicKey = String

public protocol UnifiedViewingKey {
    var extfvk: ExtendedFullViewingKey { get set }
    var extpub: ExtendedPublicKey { get set }
}

public typealias TransparentAddress = String
public typealias SaplingShieldedAddress = String

public protocol UnifiedAddress {
    var tAddress: TransparentAddress { get }
    var zAddress: SaplingShieldedAddress { get }
}

public protocol WalletBalance {
    var verified: Int64 { get set }
    var total: Int64 { get set }
}
