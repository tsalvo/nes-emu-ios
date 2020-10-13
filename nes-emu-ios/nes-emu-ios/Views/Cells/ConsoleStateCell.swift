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
    private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    static private let elementLength: Int = 4
    static private let screenWidth: Int = 256
    static private let screenHeight: Int = 224
    static private let imageSize: CGSize = CGSize(width: ConsoleStateCell.screenWidth, height: ConsoleStateCell.screenHeight)
    
    // MARK: - UI Outlets
    
    @IBOutlet weak private var dateLabel: UILabel!
    @IBOutlet weak private var autoSaveLabel: UILabel!
    @IBOutlet weak private var thumbnailImageView: UIImageView!
    
    // MARK: - Class Variables
    
    class var reuseIdentifier: String { return String(describing: self) }
    
    // MARK: - Public Variables
    
    var date: Date?
    {
        didSet
        {
            guard let safeData = self.date
                else
            {
                self.dateLabel.text = ""
                return
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            self.dateLabel.text = dateFormatter.string(from: safeData)
        }
    }
    
    var isAutosave: Bool = false
    {
        didSet
        {
            self.autoSaveLabel.isHidden = !self.isAutosave
            self.autoSaveLabel.text = self.isAutosave ? NSLocalizedString("label-autosave", comment: "autosave") : ""
        }
    }
    
    var buffer: [UInt32]?
    {
        didSet
        {
            guard let _ = self.buffer else { return }
            let image = CIImage(bitmapData: NSData(bytes: &self.buffer!, length: ConsoleStateCell.screenWidth * ConsoleStateCell.screenHeight * ConsoleStateCell.elementLength) as Data, bytesPerRow: ConsoleStateCell.screenWidth * ConsoleStateCell.elementLength, size: ConsoleStateCell.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
            self.thumbnailImageView.image = UIImage(ciImage: image)
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
        self.autoSaveLabel.textColor = UIColor.secondaryLabel
    }
}
