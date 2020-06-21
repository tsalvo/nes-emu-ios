//
//  SettingsToggleCell.swift
//  October
//
//  Created by Tom Salvo on 5/12/19.
//  Copyright © 2019 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsToggleCell: UITableViewCell
{
    // MARK: - UI Outlets
    
    @IBOutlet weak private var settingLabel: UILabel!
    @IBOutlet weak private var settingDescriptionLabel: UILabel!
    @IBOutlet weak private var settingToggleSwitch: UISwitch!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Public Variables
    
    var settingText: String = ""
    {
        didSet
        {
            self.settingLabel.text = self.settingText
        }
    }
    
    var settingDescriptionText: String?
    {
        didSet
        {
            if let safeText = self.settingDescriptionText
            {
                self.settingDescriptionLabel.text = safeText
                self.settingDescriptionLabel.isHidden = false
            }
            else
            {
                self.settingDescriptionLabel.isHidden = true
            }
        }
    }
    
    var settingKey: String?
    {
        didSet
        {
            if let safeKey = self.settingKey
            {
                self.settingToggleSwitch.setOn(UserDefaults.standard.bool(forKey:safeKey), animated: false)
                self.settingToggleSwitch.isEnabled = true
            }
            else
            {
                self.settingToggleSwitch.isEnabled = false
            }
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
    
    // MARK: - Button Actions
    
    @IBAction private func toggleChanged(_ sender: AnyObject)
    {
        if let safeSettingKey = self.settingKey,
            let safeToggle = sender as? UISwitch
        {
            UserDefaults.standard.set(safeToggle.isOn, forKey: safeSettingKey)
        }
    }
    
    // MARK: - Private Functions
    
    private func setupUI()
    {
        self.settingToggleSwitch.tintColor = UIColor.init(named: "AppTint")
        self.settingLabel.textColor = UIColor.label
        self.settingDescriptionLabel.textColor = UIColor.secondaryLabel
    }
}

