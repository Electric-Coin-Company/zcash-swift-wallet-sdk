//
//  CompactBlockEntity.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 11/16/19.
//

import Foundation

protocol CompactBlockEntity {
    var height: BlockHeight { get set }
    var data: Data { get set }
}
