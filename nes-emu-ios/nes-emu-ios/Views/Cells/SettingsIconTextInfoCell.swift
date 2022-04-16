//
//  SettingsIconTextInfoCell.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 12/28/19.
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

final class SettingsIconTextInfoCell: UITableViewCell
{
    // MARK: - UI Outlets
    
    @IBOutlet weak private var iconHorizontalStackView: UIStackView!
    @IBOutlet weak private var headerLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Public Variables
    
    var iconImageNames: [String]?
    {
        didSet
        {
            guard let safeIconImageNames = self.iconImageNames,
                safeIconImageNames.count > 0
            else
            {
                self.iconHorizontalStackView.isHidden = true
                return
            }
            
            self.iconHorizontalStackView.safelyRemoveArrangedSubviews()
            
            for iconImage in safeIconImageNames.compactMap({ UIImage.init(systemName: $0, withConfiguration: UIImage.SymbolConfiguration.init(weight: .semibold)) })
            {
                self.iconHorizontalStackView.addArrangedSubview(UIImageView.init(image: iconImage))
            }
            
            let v = UIView()
            v.backgroundColor = UIColor.clear
            v.isUserInteractionEnabled = false
            self.iconHorizontalStackView.addArrangedSubview(v)
            self.iconHorizontalStackView.isHidden = false
        }
    }
    
    var headerText: String = ""
    {
        didSet
        {
            self.headerLabel.text = self.headerText
        }
    }
    
    var descriptionText: String = ""
    {
        didSet
        {
            self.descriptionLabel.text = self.descriptionText
        }
    }
    
    // MARK: - Life Cycle
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.backgroundColor = .clear
        self.backgroundView?.backgroundColor = .clear
        self.setupUI()
    }
    
    // MARK: - Private Functions
    
    private func setupUI()
    {
        self.iconHorizontalStackView.isHidden = self.iconImageNames == nil || (self.iconImageNames ?? []).count == 0
        self.iconHorizontalStackView.tintColor = UIColor.secondaryLabel
        self.headerLabel.textColor = UIColor.label
        self.descriptionLabel.textColor = UIColor.secondaryLabel
    }
}
