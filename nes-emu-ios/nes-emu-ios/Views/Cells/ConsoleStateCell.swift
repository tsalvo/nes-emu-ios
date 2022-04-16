//
//  ConsoleStateCell.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
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

final class ConsoleStateCell: UITableViewCell
{
    private let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
    static private let elementLength: Int = 4
    static private let imageSize: CGSize = CGSize(width: PPU.screenWidth, height: PPU.screenHeight)
    
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
            let image = CIImage(bitmapData: NSData(bytes: &self.buffer!, length: PPU.screenWidth * PPU.screenHeight * ConsoleStateCell.elementLength) as Data, bytesPerRow: PPU.screenWidth * ConsoleStateCell.elementLength, size: ConsoleStateCell.imageSize, format: CIFormat.ARGB8, colorSpace: self.rgbColorSpace)
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
