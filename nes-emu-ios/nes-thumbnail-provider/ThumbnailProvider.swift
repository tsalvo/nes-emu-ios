//
//  ThumbnailProvider.swift
//  nes-thumbnail-provider
//
//  Created by Tom Salvo on 6/13/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import UIKit
import QuickLookThumbnailing
import os

enum MirroringMode: UInt8
{
    case horizontal = 0,
    vertical = 1,
    single0 = 2,
    single1 = 3,
    fourScreen = 4
}

struct RomHeader
{
    init(fromData aData: Data)
    {
        let bytes: [UInt8] = [UInt8](aData)
        
        // check for header length and N,E,S,0x1a start of file
        guard bytes.count >= 16,
            bytes[0] == 0x4E, // N
            bytes[1] == 0x45, // E
            bytes[2] == 0x53, // S
            bytes[3] == 0x1A
        else
        {
            self.mapperIdentifier = 0 // MapperIdentifier.NROM
            self.mirroringMode = .horizontal
            self.hasTrainer = false
            self.hasBattery = false
            self.numChrBlocks = 0
            self.numPrgBlocks = 0
            return
        }
        
        var mapper: UInt8 = 0
        
        let byte6LittleEndianBits: [Bool] = bytes[6].littleEndianBitArray
        let byte7LittleEndianBits: [Bool] = bytes[7].littleEndianBitArray
        
        let numPrgBlocks: UInt8 = bytes[4]
        let numChrBlocks: UInt8 = bytes[5]
        let mirroringMode: MirroringMode = byte6LittleEndianBits[3] ? .fourScreen : (byte6LittleEndianBits[0] ? .vertical : .horizontal)
        let hasBattery: Bool = byte6LittleEndianBits[1]
        let hasTrainer: Bool = byte6LittleEndianBits[2]
        
        mapper += byte6LittleEndianBits[4] ? 1 : 0
        mapper += byte6LittleEndianBits[5] ? 2 : 0
        mapper += byte6LittleEndianBits[6] ? 4 : 0
        mapper += byte6LittleEndianBits[7] ? 8 : 0
        mapper += byte7LittleEndianBits[4] ? 16 : 0
        mapper += byte7LittleEndianBits[5] ? 32 : 0
        mapper += byte7LittleEndianBits[6] ? 64 : 0
        mapper += byte7LittleEndianBits[7] ? 128 : 0
        
        self.numChrBlocks = numChrBlocks
        self.numPrgBlocks = numPrgBlocks
        self.mapperIdentifier = mapper // MapperIdentifier.init(rawValue: mapper) ?? MapperIdentifier.NROM
        self.mirroringMode = mirroringMode
        self.hasTrainer = hasTrainer
        self.hasBattery = hasBattery
    }
    
    let numPrgBlocks: UInt8
    let numChrBlocks: UInt8
    let mapperIdentifier: UInt8
    let mirroringMode: MirroringMode
    let hasTrainer: Bool
    let hasBattery: Bool
}

class ThumbnailProvider: QLThumbnailProvider
{
    private class ThumbnailView: UIView
    {
        let romHeader: RomHeader
        
        init(frame aFrame: CGRect, romHeader aRomheader: RomHeader)
        {
            self.romHeader = aRomheader
            super.init(frame: aFrame)
            self.backgroundColor = UIColor.systemBackground
        }
        
        required init?(coder aDecoder: NSCoder) {
            os_log(OSLogType.error, "Thumbnail Provider - init(coder:) has not been implemented")
            fatalError("init(coder:) has not been implemented")
        }
        
        override func draw(_ rect: CGRect)
        {
            super.draw(rect)

            let topMargin: CGFloat = 6.0
            let textHeight: CGFloat = 13.0
            let lineVerticalSpacing: CGFloat = 2.0
            let lineHeight: CGFloat = textHeight + lineVerticalSpacing
            let leadingMargin: CGFloat = 6.0
            
            let titleFont: UIFont = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
            let bodyFont: UIFont = UIFont.systemFont(ofSize: 11.0, weight: .regular)
            let titleAttrs: [NSAttributedString.Key : Any] = [.font: titleFont, .foregroundColor: UIColor.label]
            let bodyAttrs: [NSAttributedString.Key : Any] = [.font: bodyFont, .foregroundColor: UIColor.secondaryLabel]
            
            let nesRomStr: String = "NES ROM"
            let mapperStr: String = "Mapper \(self.romHeader.mapperIdentifier)"
            let prgStr: String = "PRG \(self.romHeader.numPrgBlocks)x16KB"
            let chrStr: String = "CHR \(self.romHeader.numChrBlocks)x8KB"
            let batteryStr: String = "Battery"
            
            nesRomStr.draw(with: CGRect(origin: CGPoint(x: leadingMargin, y: topMargin) , size: nesRomStr.boundingRect(with: CGSize(width: rect.width - (leadingMargin * 2.0), height: textHeight), options: [.usesLineFragmentOrigin], attributes: titleAttrs, context: nil).size), options: [.usesLineFragmentOrigin], attributes: titleAttrs, context: nil)
            mapperStr.draw(with: CGRect(origin: CGPoint(x: leadingMargin, y: topMargin + (lineHeight * 1.0)) , size: mapperStr.boundingRect(with: CGSize(width: rect.width - (leadingMargin * 2.0), height: textHeight), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil).size), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil)
            prgStr.draw(with: CGRect(origin: CGPoint(x: leadingMargin, y: topMargin + (lineHeight * 2.0)) , size: prgStr.boundingRect(with: CGSize(width: rect.width - (leadingMargin * 2.0), height: textHeight), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil).size), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil)
            chrStr.draw(with: CGRect(origin: CGPoint(x: leadingMargin, y: topMargin + (lineHeight * 3.0)) , size: chrStr.boundingRect(with: CGSize(width: rect.width - (leadingMargin * 2.0), height: textHeight), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil).size), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil)
            if (self.romHeader.hasBattery)
            {
                batteryStr.draw(with: CGRect(origin: CGPoint(x: leadingMargin, y: topMargin + (lineHeight * 4.0)) , size: batteryStr.boundingRect(with: CGSize(width: rect.width - (leadingMargin * 2.0), height: textHeight), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil).size), options: [.usesLineFragmentOrigin], attributes: bodyAttrs, context: nil)
            }
            
            
        }
    }
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // Draw the thumbnail into the current context, set up with UIKit's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
            
            let romData: Data
            
            do
            {
                romData = try Data.init(contentsOf: request.fileURL)
            }
            catch
            {
                return false
            }
            
            let tView = ThumbnailView(frame: CGRect(origin: .zero, size: request.maximumSize), romHeader: RomHeader.init(fromData: romData.prefix(16)))
            
            tView.draw(tView.bounds)
            
            return true
        }), nil)
    }
}
