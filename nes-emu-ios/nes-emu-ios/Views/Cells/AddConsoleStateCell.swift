//
//  AddConsoleStateCell.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class AddConsoleStateCell: UITableViewCell
{

    // MARK: - UI Outlets
    
    @IBOutlet weak private var saveStateLabel: UILabel!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Public Variables
    
    var saveStateText: String?
    {
        didSet
        {
            self.saveStateLabel.text = saveStateText ?? ""
        }
    }

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
        self.saveStateLabel.textColor = UIColor.label
    }
    
    
}
