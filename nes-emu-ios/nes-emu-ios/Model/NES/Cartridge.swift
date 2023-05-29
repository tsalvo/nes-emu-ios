//
//  Cartridge.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/4/20.
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

import Foundation

protocol CartridgeProtocol
{
    var header: RomHeader { get }
    var prgBlocks: [[UInt8]] { get }
    var chrBlocks: [[UInt8]] { get set }
}

struct Cartridge: CartridgeProtocol
{
    init(fromData aData: Data)
    {
        let header = RomHeader(fromData: aData.prefix(RomHeader.sizeInBytes))
        self.header = header
        self.md5 = aData.md5
        
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
    
    func mapper(withState aState: MapperState? = nil) -> MapperProtocol
    {
        guard let safeMapperIdentifier: MapperIdentifier = self.header.mapperIdentifier,
            safeMapperIdentifier.isSupported
        else
        {
            return Mapper_UnsupportedPlaceholder(withCartridge: self)
        }
        
        switch self.header.mapperIdentifier
        {
        case .NROM:
            return Mapper_NROM(withCartridge: self, state: aState)
        case .UxROM:
            return Mapper_UNROM(withCartridge: self, state: aState)
        case .MMC1:
            return Mapper_MMC1(withCartridge: self, state: aState)
        case .CNROM:
            return Mapper_CNROM(withCartridge: self, state: aState)
        case .MMC3:
            return Mapper_MMC3(withCartridge: self, state: aState)
        case .AxROM:
            return Mapper_AxROM(withCartridge: self, state: aState)
        case .MMC2:
            return Mapper_MMC2(withCartridge: self, state: aState)
        case .MMC4:
            return Mapper_MMC4(withCartridge: self, state: aState)
        case .ColorDreams, .GxROM:
            return Mapper_ColorDreams_GxROM(withCartridge: self, state: aState)
        case .MMC5:
            return Mapper_MMC5(withCartridge: self, state: aState)
        case .VRC2b_VRC4e_VRC4f:
            return Mapper_VRC2b_VRC4e_VRC4f(withCartridge: self, state: aState)
        case .VRC2c_VRC4b_VRC4d:
            return Mapper_VRC2c_VRC4b_VRC4d(withCartridge: self, state: aState)
        case .VRC7:
            return Mapper_VRC7(withCartridge: self, state: aState)
        case ._078:
            return Mapper_78(withCartridge: self, state: aState)
        case ._087:
            return Mapper_87(withCartridge: self, state: aState)
        case .TxSROM:
            return Mapper_TxSROM(withCartridge: self, state: aState)
        case .TQROM:
            return Mapper_TQROM(withCartridge: self, state: aState)
        case .Namcot118_TengenMimic1:
            return Mapper_Namcot118_TengenMimic1(withCartridge: self, state: aState)
        case .NTDEC_2722:
            return Mapper_NTDEC2722(withCartridge: self, state: aState)
        case .CamericaQuattro:
            return Mapper_CamericaQuattro(withCartridge: self, state: aState)
        default:
            return Mapper_UnsupportedPlaceholder(withCartridge: self, state: aState)
        }
    }
    
    let md5: String
    let header: RomHeader
    let trainerData: Data
    let prgBlocks: [[UInt8]]
    var chrBlocks: [[UInt8]]
    let isValid: Bool
}
