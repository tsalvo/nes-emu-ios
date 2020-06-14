//
//  Cartridge.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol CartridgeProtocol: class
{
    var mirroringMode: MirroringMode { get }
    var prgBlocks: [[UInt8]] { get }
    var chrBlocks: [[UInt8]] { get set }
    var hasBattery: Bool { get }
}

class Cartridge: CartridgeProtocol
{
    init(fromData aData: Data)
    {
        let bytes: [UInt8] = [UInt8](aData)
        self.data = aData
        
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
            self.chrBlocks = []
            self.prgBlocks = []
            self.trainerData = Data()
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
        
        self.mapperIdentifier = MapperIdentifier.init(rawValue: mapper) ?? MapperIdentifier.NROM
        self.mirroringMode = mirroringMode
        self.hasTrainer = hasTrainer
        self.hasBattery = hasBattery
        
        let prgBlockSize: Int = 16384
        let chrBlockSize: Int = 8192
        let headerSize: Int = 16
        let trainerSize: Int = hasTrainer ? 512 : 0
        let totalPrgSize: Int = Int(numPrgBlocks) * prgBlockSize
        let totalChrSize: Int = Int(numChrBlocks) * chrBlockSize
        let trainerOffset: Int = 16 // trainer (if present) comes after header
        let prgOffset: Int = trainerOffset + trainerSize // prg blocks come after trainer (if present)
        let chrOffset: Int = prgOffset + totalPrgSize // chr blocks come after prg blocks
        
        let expectedFileSizeOfEntireRomInBytes: Int = headerSize + trainerSize + totalPrgSize + totalChrSize
        
        // make sure the the total file size adds up to what the header indicates
        guard expectedFileSizeOfEntireRomInBytes == aData.count
            else
        {
            self.chrBlocks = []
            self.prgBlocks = []
            self.trainerData = Data()
            self.isValid = false
            return
        }
        
        self.trainerData = hasTrainer ? aData.subdata(in: trainerOffset ..< prgOffset) : Data()
        
        var pBlocks: [[UInt8]] = []
        for i in 0 ..< Int(numPrgBlocks)
        {
            let offset: Int = prgOffset + (i * prgBlockSize)
            pBlocks.append([UInt8](aData.subdata(in: offset ..< offset + prgBlockSize)))
        }
        
        var cBlocks: [[UInt8]] = []
        for i in 0 ..< Int(numChrBlocks)
        {
            let offset: Int = chrOffset + (i * chrBlockSize)
            cBlocks.append([UInt8](aData.subdata(in: offset ..< offset + chrBlockSize)))
        }
        
        self.prgBlocks = pBlocks
        self.chrBlocks = cBlocks
        
        self.isValid = true
    }
    
    let data: Data
    let trainerData: Data
    let prgBlocks: [[UInt8]]
    var chrBlocks: [[UInt8]]
    let mapperIdentifier: MapperIdentifier
    let mirroringMode: MirroringMode
    let hasTrainer: Bool
    let hasBattery: Bool
    let isValid: Bool
}
