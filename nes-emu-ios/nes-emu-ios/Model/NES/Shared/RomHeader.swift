//
//  RomHeader.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/14/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct RomHeader
{
    static let sizeInBytes: Int = 16
    let numPrgBlocks: UInt8
    let numChrBlocks: UInt8
    let mapperIdentifier: MapperIdentifier
    let mirroringMode: MirroringMode
    let hasTrainer: Bool
    let hasBattery: Bool
    let isValid: Bool
    
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
            self.mapperIdentifier = MapperIdentifier.NROM
            self.mirroringMode = .horizontal
            self.hasTrainer = false
            self.hasBattery = false
            self.numChrBlocks = 0
            self.numPrgBlocks = 0
            self.isValid = false
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
        self.mapperIdentifier = MapperIdentifier.init(rawValue: mapper) ?? MapperIdentifier.NROM
        self.mirroringMode = mirroringMode
        self.hasTrainer = hasTrainer
        self.hasBattery = hasBattery
        self.isValid = true
    }
}
