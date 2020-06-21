//
//  SettingsSegmentedTableCell.swift
//  October
//
//  Created by Tom Salvo on 6/26/19.
//  Copyright © 2019 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsSegmentedCell: UITableViewCell
{
    // MARK: - UI Outlets
    
    @IBOutlet weak private var settingLabel: UILabel!
    @IBOutlet weak private var settingDescriptionLabel: UILabel!
    @IBOutlet weak private var segmentedControl: UISegmentedControl!
    
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
    
    var settingTuple: (key: String, values: [SettingsEnum])?
    {
        didSet
        {
            guard let safeSettingTuple = self.settingTuple else { return }
            
            self.segmentedControl.removeAllSegments()
            for (index, item) in safeSettingTuple.values.enumerated()
            {
                self.segmentedControl.insertSegment(withTitle: item.friendlyName, at: index, animated: false)
            }
            
            if let t = safeSettingTuple.values.first?.storedValue
            {
                if t is String,
                    let selectedValue = UserDefaults.standard.string(forKey: safeSettingTuple.key),
                    let selectedIndex = safeSettingTuple.values.firstIndex(where: { $0.storedValue as? String == selectedValue })
                {
                    self.segmentedControl.selectedSegmentIndex = selectedIndex
                }
                else if t is Int,
                    let selectedIndex = safeSettingTuple.values.firstIndex(where: { $0.storedValue as? Int == UserDefaults.standard.integer(forKey: safeSettingTuple.key) } )
                {
                    self.segmentedControl.selectedSegmentIndex = selectedIndex
                }
                else
                {
                    self.segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
                }
            }
            else
            {
                self.segmentedControl.selectedSegmentIndex = UISegmentedControl.noSegment
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
    
    // MARK: - Private Functions
    
    @IBAction private func segmentedControlValueChanged(_ sender: AnyObject?)
    {
        guard let safeKey: String = self.settingTuple?.key,
            let safeStoredValue: Any = self.settingTuple?.values[safe: self.segmentedControl.selectedSegmentIndex]?.storedValue else { return }
        UserDefaults.standard.set(safeStoredValue, forKey: safeKey)
    }
    
    private func setupUI()
    {
        self.settingLabel.textColor = UIColor.label
        
        self.segmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: .selected)
        self.segmentedControl.backgroundColor = UIColor.secondarySystemBackground
        self.segmentedControl.selectedSegmentTintColor = UIColor.init(named: "AppTint")
    }
}
