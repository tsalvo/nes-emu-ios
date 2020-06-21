//
//  SettingsAboutCell.swift
//  October
//
//  Created by Tom Salvo on 5/12/19.
//  Copyright © 2019 Tom Salvo. All rights reserved.
//

import UIKit

class SettingsAboutCell: UITableViewCell
{
    // MARK: - UI Outlets
    
    @IBOutlet weak private var aboutLabel1: UILabel!
    @IBOutlet weak private var aboutLabel2: UILabel!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Life Cycle
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        self.backgroundColor = .clear
        self.backgroundView?.backgroundColor = .clear
        self.setupUI()
    }
    
    var aboutText1: String = ""
    {
        didSet
        {
            self.aboutLabel1.text = self.aboutText1
        }
    }
    
    var aboutText2: String = ""
    {
        didSet
        {
            self.aboutLabel2.text = self.aboutText2
        }
    }
    
    // MARK: - Private Functions
    
    private func setupUI()
    {
        self.aboutLabel1.textColor = UIColor.label
        self.aboutLabel2.textColor = UIColor.label
    }
}

