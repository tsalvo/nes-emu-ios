//
//  ConsoleStateCell.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit

class ConsoleStateCell: UITableViewCell
{
    // MARK: - UI Outlets
    
    @IBOutlet weak private var dateLabel: UILabel!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Public Variables
    
    var date: Date?
    {
        didSet
        {
            self.dateLabel.text = self.date?.description ?? ""
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
        self.dateLabel.textColor = UIColor.label
    }
    
}
