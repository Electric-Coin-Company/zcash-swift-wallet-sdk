//
//  SynchronizerCell.swift
//  ZcashLightClientSample
//
//  Created by Michal Fousek on 24.03.2023.
//  Copyright © 2023 Electric Coin Company. All rights reserved.
//

import Foundation
import UIKit

class SynchronizerCell: UITableViewCell {
    @IBOutlet var alias: UILabel!
    @IBOutlet var status: UILabel!
    @IBOutlet var button: UIButton!

    var indexPath: IndexPath?
    var didTapOnButton: ((IndexPath) -> Void)?

    @IBAction func buttonTap() {
        guard let indexPath else { return }
        didTapOnButton?(indexPath)
    }
}
