//
//  NESCartridge.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation



enum Mapper: UInt8
{
    // see https://wiki.nesdev.com/w/index.php/List_of_mappers
    case NROM = 0,
    MMC1 = 1,
    UxROM = 2,
    CNROM = 3,
    MMC3 = 4,
    MMC5 = 5,
    AxROM = 7,
    MMC2 = 9,
    MMC4 = 10,
    ColorDreams = 11,
    CPROM = 13,
    Multi100In1ContraFunction16 = 15,
    BandaiEPROM = 16,
    JalecoSS8806 = 18,
    Namco163 = 19,
    VRC4a_VRC4c = 21,
    VRC2a = 22,
    VRC2b_VRC4e = 23,
    VRC6a = 24,
    VRC4b_VRC4d = 25,
    VRC6b = 26,
    BNROM_NINA001 = 34,
    RAMBO1 = 64
    
    var isSupportedByThisEmulator: Bool
    {
        switch self
        {
        case .NROM: return true
        default: return false
        }
    }
    
    var hasExpansionAudio: Bool
    {
        switch self
        {
        case .Namco163, .VRC6a, .VRC6b, .MMC5: return true
        default: return false
        }
    }
}

struct NesRomHeader
{
    let numPrgBlocks: UInt8
    let numChrBlocks: UInt8
    let mapper: UInt8 // TODO: change to Mapper enum
    let mirroringMode: MirroringMode
    let hasTrainer: Bool
    let hasBattery: Bool
}

struct NESCartridge
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
            self.header = NesRomHeader(numPrgBlocks: 0, numChrBlocks: 0, mapper: 0, mirroringMode: .horizontal, hasTrainer: false, hasBattery: false)
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
        
        self.header = NesRomHeader(numPrgBlocks: numPrgBlocks, numChrBlocks: numChrBlocks, mapper: mapper, mirroringMode: mirroringMode, hasTrainer: hasTrainer, hasBattery: hasBattery)
        
        let prgBlockSize: Int = 16384
        let chrBlockSize: Int = 8192
        let headerSize: Int = 16
        let trainerSize: Int = hasTrainer ? 512 : 0
        let totalPrgSize: Int = Int(numPrgBlocks) * prgBlockSize
        let totalChrSize: Int = Int(numChrBlocks) * chrBlockSize
        let trainerOffset: Int = 16 // trainer (if present) comes after header
        let prgOffset: Int = trainerOffset + trainerSize // prg blocks come after trainer (if present)
        let chrOffset: Int = prgOffset + totalChrSize // chr blocks come after prg blocks
        
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
        
        var pBlocks: [Data] = []
        for i in 0 ..< Int(numPrgBlocks)
        {
            let offset: Int = prgOffset + (i * prgBlockSize)
            pBlocks.append(aData.subdata(in: offset ..< offset + prgBlockSize))
        }
        
        var cBlocks: [Data] = []
        for i in 0 ..< Int(numChrBlocks)
        {
            let offset: Int = chrOffset + (i * chrBlockSize)
            cBlocks.append(aData.subdata(in: offset ..< offset + chrBlockSize))
        }
        
        self.prgBlocks = pBlocks
        self.chrBlocks = cBlocks
        
        self.isValid = true
    }
    
    let data: Data
    let trainerData: Data
    let prgBlocks: [Data]
    let chrBlocks: [Data]
    let header: NesRomHeader
    let isValid: Bool
}
