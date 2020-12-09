//
//  DerivationToolViewController.swift
//  ZcashLightClientSample
//
//  Created by Francisco Gindre on 12/9/20.
//  Copyright © 2020 Electric Coin Company. All rights reserved.
//

import UIKit
import ZcashLightClientKit
import MnemonicSwift
class DerivationToolViewController: UIViewController {
    
    enum DerivationErrors: Error {
        case couldNotDeriveSpendingKeys(underlyingError: Error)
        case couldNotDeriveViewingKeys(underlyingError: Error)
        case couldNotDeriveShieldedAddress(underlyingError: Error)
        case couldNotDeriveTransparentAddress(underlyingError: Error)
        case unknown
    }
    @IBOutlet weak var seedTextView: UITextView!
    @IBOutlet weak var seedTextLabel: UILabel!
    @IBOutlet weak var shieldedAddressLabel: UILabel!
    @IBOutlet weak var transparentAddressLabel: UILabel!
    @IBOutlet weak var spendingKeyLabel: UILabel!
    @IBOutlet weak var extendedFullViewingKeyLabel: UILabel!
    @IBOutlet weak var deriveButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        deriveButton.isEnabled = isValidSeed(seedTextView.text)
        updateValidationUI()
    }
    @IBAction func spendingKeyTapped(_ gesture: UIGestureRecognizer) {
        
        loggerProxy.event("spending key copied to clipboard")
        
        UIPasteboard.general.string = self.spendingKeyLabel.text
        
        let alert = UIAlertController(title: "", message: "Spending Key Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func viewingKeyTapped(_ gesture: UIGestureRecognizer) {
        
        loggerProxy.event("extended full viewing key copied to clipboard")
        
        UIPasteboard.general.string = self.extendedFullViewingKeyLabel.text
        
        let alert = UIAlertController(title: "", message: "extended full viewing key copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func zAddressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("zAddress copied to clipboard")
        UIPasteboard.general.string = self.shieldedAddressLabel.text
        let alert = UIAlertController(title: "", message: "zAddress Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func tAddressTapped(_ gesture: UIGestureRecognizer) {
        loggerProxy.event("tAddress copied to clipboard")
        UIPasteboard.general.string = self.transparentAddressLabel.text
        let alert = UIAlertController(title: "", message: "tAddress Copied to clipboard", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func deriveButtonTapped(_ sender: Any) {
        do {
            try deriveFrom(seedPhrase: seedTextView.text)
            
        } catch {
            fail(error)
            
            clearLabels()
        }
    }
    
    func deriveFrom(seedPhrase: String) throws {
        

        let seedBytes = try Mnemonic.deterministicSeedBytes(from: seedPhrase)
        guard let spendingKey = try DerivationTool.default.deriveSpendingKeys(seed: seedBytes, numberOfAccounts: 1).first else {
            throw DerivationErrors.couldNotDeriveSpendingKeys(underlyingError: DerivationErrors.unknown)
        }
        guard let viewingKey = try DerivationTool.default.deriveViewingKeys(seed: seedBytes, numberOfAccounts: 1).first else {
            throw DerivationErrors.couldNotDeriveViewingKeys(underlyingError: DerivationErrors.unknown)
        }
        
        let shieldedAddress = try DerivationTool.default.deriveShieldedAddress(viewingKey: viewingKey)
        
        let transparentAddress = try DerivationTool.default.deriveTransparentAddress(seed: seedBytes)
        
        
        updateLabels(spendingKey: spendingKey,
                     viewingKey: viewingKey,
                     shieldedAddress: shieldedAddress,
                     transaparentAddress: transparentAddress)
        
    }
    
    func updateLabels(spendingKey: String = "",
                      viewingKey: String = "",
                      shieldedAddress: String = "",
                      transaparentAddress: String = "") {
        spendingKeyLabel.text = spendingKey
        extendedFullViewingKeyLabel.text = viewingKey
        shieldedAddressLabel.text = shieldedAddress
        transparentAddressLabel.text = transaparentAddress
    }
    
    func clearLabels() {
       updateLabels()
    }
    
    func fail(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: "\(error)", preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
    }
    
    func setValidSeed() {
        seedTextLabel.text = "This is a valid seed phrase"
        seedTextLabel.textColor = UIColor.systemGreen
    }
    
    func setInvalidSeed() {
        seedTextLabel.text = "Invalid seed phrase"
        seedTextLabel.textColor = UIColor.red
    }
    
    func isValidSeed(_ seed: String) -> Bool {
        do {
            try Mnemonic.validate(mnemonic: seed)
        } catch {
            return false
        }
        return true
    }
    
    func updateValidationUI() {
        guard isValidSeed(seedTextView.text)  else {
            setInvalidSeed()
            return
        }
        setValidSeed()
    }
}


extension DerivationToolViewController: UITextViewDelegate {
    func textViewDidEndEditing(_ textView: UITextView) {
        updateValidationUI()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        deriveButton.isEnabled = isValidSeed(textView.text)
    }
}
