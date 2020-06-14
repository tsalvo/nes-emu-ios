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
    var header: RomHeader { get }
    var prgBlocks: [[UInt8]] { get }
    var chrBlocks: [[UInt8]] { get set }
}

class Cartridge: CartridgeProtocol
{
    init(fromData aData: Data)
    {
        let header = RomHeader(fromData: aData.prefix(RomHeader.sizeInBytes))
        self.data = aData
        self.header = header
        
        guard header.isValid
            else
        {
            
            self.chrBlocks = []
            self.prgBlocks = []
            self.trainerData = Data()
            self.isValid = false
            return
        }
        
        let prgBlockSize: Int = 16384
        let chrBlockSize: Int = 8192
        let headerSize: Int = RomHeader.sizeInBytes
        let trainerSize: Int = header.hasTrainer ? 512 : 0
        let totalPrgSize: Int = Int(header.numPrgBlocks) * prgBlockSize
        let totalChrSize: Int = Int(header.numChrBlocks) * chrBlockSize
        let trainerOffset: Int = RomHeader.sizeInBytes // trainer (if present) comes after header
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
        
        self.trainerData = header.hasTrainer ? aData.subdata(in: trainerOffset ..< prgOffset) : Data()
        
        var pBlocks: [[UInt8]] = []
        for i in 0 ..< Int(header.numPrgBlocks)
        {
            let offset: Int = prgOffset + (i * prgBlockSize)
            pBlocks.append([UInt8](aData.subdata(in: offset ..< offset + prgBlockSize)))
        }
        
        var cBlocks: [[UInt8]] = []
        for i in 0 ..< Int(header.numChrBlocks)
        {
            let offset: Int = chrOffset + (i * chrBlockSize)
            cBlocks.append([UInt8](aData.subdata(in: offset ..< offset + chrBlockSize)))
        }
        
        self.prgBlocks = pBlocks
        self.chrBlocks = cBlocks
        
        self.isValid = true
    }
    
    var mapper: MapperProtocol
    {
        guard self.header.mapperIdentifier.isSupported else { return Mapper_UnsupportedPlaceholder(withCartridge: self) }
        
        switch self.header.mapperIdentifier
        {
            case .NROM:
                return Mapper_NROM(withCartridge: self)
            case .MMC1:
                return Mapper_MMC1(withCartridge: self)
            default: return Mapper_UnsupportedPlaceholder(withCartridge: self)
        }
    }
    
    let header: RomHeader
    let data: Data
    let trainerData: Data
    let prgBlocks: [[UInt8]]
    var chrBlocks: [[UInt8]]
    let isValid: Bool
}
