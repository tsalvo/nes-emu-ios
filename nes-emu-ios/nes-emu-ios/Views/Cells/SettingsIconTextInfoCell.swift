//
//  SettingsIconTextInfoCell.swift
//  October
//
//  Created by Tom Salvo on 12/28/19.
//  Copyright © 2019 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsIconTextInfoCell: UITableViewCell
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
