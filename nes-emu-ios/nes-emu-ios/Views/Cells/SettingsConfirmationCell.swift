//
//  SettingsConfirmationCell.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/21/20.
//  Copyright © 2020 Tom Salvo.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit

protocol SettingsConfirmationDelegate: AnyObject
{
    func confirmationButtonPressed(forKey aKey: String, message aMessage: String, confirmationBlock aConfirmationBlock: (() -> Void)?)
}

final class SettingsConfirmationCell: UITableViewCell
{
    @IBOutlet weak private var settingLabel: UILabel!
    @IBOutlet weak private var settingConfirmationButton: UIButton!
    @IBOutlet weak private var settingConfirmationSwitch: UISwitch!
    
    weak var confirmationDelegate: SettingsConfirmationDelegate?
    
    var settingText: String?
    {
        didSet
        {
            self.settingLabel.text = self.settingText ?? ""
        }
    }
    
    var buttonText: String?
    {
        didSet
        {
            if let safeText = self.buttonText,
               let safeToggle = self.settingConfirmationSwitch
            {
                self.settingConfirmationButton.setTitle(safeText, for: .normal)
                self.settingConfirmationButton.isEnabled = safeToggle.isOn
                self.settingConfirmationButton.isHidden = !safeToggle.isOn
            }
            else
            {
                self.settingConfirmationButton.isEnabled = false
                self.settingConfirmationButton.isHidden = true
            }
        }
    }
    
    var settingKey: String?
    var confirmationBlock: (() -> Void)?
    
    // MARK: - Button Actions
    @IBAction private func toggleChanged(_ sender: AnyObject)
    {
        if let safeToggle = sender as? UISwitch
        {
            self.settingConfirmationButton.isEnabled = safeToggle.isOn
            self.settingConfirmationButton.isHidden = !safeToggle.isOn
        }
    }
    
    @IBAction private func buttonPressed(_ sender: AnyObject?)
    {
        guard let safeKey = self.settingKey,
              let safeMessage = self.settingText else { return }
        self.settingConfirmationButton.isEnabled = false
        self.settingConfirmationButton.isHidden = true
        self.settingConfirmationSwitch.isOn = false
        self.confirmationDelegate?.confirmationButtonPressed(forKey: safeKey, message: safeMessage, confirmationBlock: self.confirmationBlock)
    }
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Life Cycle
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.settingLabel.textColor = UIColor.label
    }
}
