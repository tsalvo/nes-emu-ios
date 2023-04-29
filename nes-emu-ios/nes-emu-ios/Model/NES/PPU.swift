//
//  PPU.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
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

struct PPUStepResults
{
    let requestedCPUInterrupt: Interrupt?
}

/// NES Picture Processing Unit
struct PPU
{
    private(set) var cycle: Int = 340
    private(set) var frame: UInt64 = 0
    
    /// an optimization to prevent unnecessary Mapper object type lookups and mapper step calls during frequent PPU.step() calls
    private let mapperHasStep: Bool
    private let mapperHasExtendedNametableMapping: Bool
    
    var mapper: MapperProtocol
    private var paletteData: [UInt8] = [UInt8].init(repeating: 0, count: 32)
    private var nameTableData: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    private var oamData: [UInt8] = [UInt8].init(repeating: 0, count: 256)
    
    /// for each mirroring mode, return nametable offset sequence, pre-adjusted from 0x2000 base address
    private static let nameTableOffsetSequence: [[UInt16]] = [
        [0x0000, 0x0000, 0x0400, 0x0400], // horizontal
        [0x0000, 0x0400, 0x0000, 0x0400], // vertical
        [0x0000, 0x0000, 0x0000, 0x0000], // single 0
        [0x0400, 0x0400, 0x0400, 0x0400], // single 1
        [0x0000, 0x0400, 0x0800, 0x0C00]  // 4-screen
    ]
    
    private static let nmiMaximumDelay: UInt8 = 16
    
    // MARK: PPU Registers
    
    /// current vram address (15 bit)
    private var v: UInt16 = 0
    
    /// temporary vram address (15 bit)
    private var t: UInt16 = 0
    
    /// fine x scroll (3 bit)
    private var x: UInt8 = 0
    
    /// write toggle bit
    private var w: Bool = false
    
    /// even / odd frame flag bit
    private var f: Bool = false
    
    private var register: UInt8 = 0
    
    // MARK: NMI flags
    private var nmiOccurred: Bool = false {
        didSet {
            guard self.nmiOccurred,
                  !oldValue,
                  self.nmiOutput
            else { return }
            
            self.nmiDelay = PPU.nmiMaximumDelay
        }
    }
    private var nmiOutput: Bool = false
    private var nmiDelay: UInt8 = 0
    
    // MARK: Background temporary variables
    private var nameTableByte: UInt8 = 0
    private var attributeTableByte: UInt8 = 0
    private var lowTileByte: UInt8 = 0
    private var highTileByte: UInt8 = 0
    private var tileData: UInt64 = 0
    
    // MARK: Sprite temporary variables
    private var spriteCount: Int = 0
    private var spritePatterns: [UInt32] = [UInt32].init(repeating: 0, count: 8)
    private var spritePositions: [UInt8] = [UInt8].init(repeating: 0, count: 8)
    private var spritePriorities: [UInt8] = [UInt8].init(repeating: 0, count: 8)
    private var spriteIndexes: [UInt8] = [UInt8].init(repeating: 0, count: 8)
    
    // MARK: $2000 PPUCTRL
    /// 0: $2000; 1: $2400; 2: $2800; 3: $2C00
    private var flagNameTable: UInt8 = 0
    
    /// 0: add 1; 1: add 32
    private var flagIncrement: Bool = false
    
    /// 0: $0000; 1: $1000; ignored in 8x16 mode
    private var flagSpriteTable: Bool = false
    
    /// 0: $0000; 1: $1000
    private var flagBackgroundTable: Bool = false
    
    /// 0: 8x8; 1: 8x16
    private var flagSpriteSize: Bool = false
    
    /// 0: read EXT; 1: write EXT
    private var flagMasterSlave: Bool = false
    
    // MARK: $2001 PPUMASK
    /// false: color; true: grayscale
    private var flagGrayscale: Bool = false
    
    /// false: hide; true: show
    private var flagShowLeftBackground: Bool = false
    
    /// false: hide; true: show
    private var flagShowLeftSprites: Bool = false
    
    /// false: hide; true: show
    private(set) var flagShowBackground: Bool = false
    
    /// false: hide; true: show
    private(set) var flagShowSprites: Bool = false
    
    /// false: normal; true: emphasized
    private var flagRedTint: Bool = false
    
    /// false: normal; true: emphasized
    private var flagGreenTint: Bool = false
    
    /// false: normal; true: emphasized
    private var flagBlueTint: Bool = false
    
    // MARK: $2002 PPUSTATUS
    private var flagSpriteZeroHit: UInt8 = 0
    private var flagSpriteOverflow: UInt8 = 0
    
    // $2003 OAMADDR
    private var oamAddress: UInt8 = 0
    
    // $2007 PPUDATA
    /// for buffered reads
    private var bufferedData: UInt8 = 0
    
    // MARK: Pixel Buffer
    static let screenWidth: Int = 256
    static let screenHeight: Int = 224
    static let emptyBuffer: [UInt32] = [UInt32].init(repeating: 0, count: PPU.screenWidth * PPU.screenHeight)
    private static let paletteColors: [UInt32] = [
        0x666666FF, 0x882A00FF, 0xA71214FF, 0xA4003BFF, 0x7E005CFF, 0x40006EFF, 0x00066CFF, 0x001D56FF,
        0x003533FF, 0x00480BFF, 0x005200FF, 0x084F00FF, 0x4D4000FF, 0x000000FF, 0x000000FF, 0x000000FF,
        0xADADADFF, 0xD95F15FF, 0xFF4042FF, 0xFE2775FF, 0xCC1AA0FF, 0x7B1EB7FF, 0x2031B5FF, 0x004E99FF,
        0x006D6BFF, 0x008738FF, 0x00930CFF, 0x328F00FF, 0x8D7C00FF, 0x000000FF, 0x000000FF, 0x000000FF,
        0xFFFEFFFF, 0xFFB064FF, 0xFF9092FF, 0xFF76C6FF, 0xFF6AF3FF, 0xCC6EFEFF, 0x7081FEFF, 0x229EEAFF,
        0x00BEBCFF, 0x00D888FF, 0x30E45CFF, 0x82E045FF, 0xDECD48FF, 0x4F4F4FFF, 0x000000FF, 0x000000FF,
        0xFFFEFFFF, 0xFFDFC0FF, 0xFFD2D3FF, 0xFFC8E8FF, 0xFFC2FBFF, 0xEAC4FEFF, 0xC5CCFEFF, 0xA5D8F7FF,
        0x94E5E4FF, 0x96EFCFFF, 0xABF4BDFF, 0xCCF3B3FF, 0xF2EBB5FF, 0xB8B8B8FF, 0x000000FF, 0x000000FF]
    
    /// colors in 0xBBGGRRAA format from Palette.colors
    private(set) var frontBuffer: [UInt32] = PPU.emptyBuffer
    /// colors in 0xBBGGRRAA format from Palette.colors
    private var backBuffer: [UInt32] = PPU.emptyBuffer
    private(set) var scanline: Int = 240
    
    init(mapper aMapper: MapperProtocol, state aState: PPUState? = nil)
    {
        self.mapper = aMapper
        self.mapperHasStep = aMapper.hasStep
        self.mapperHasExtendedNametableMapping = aMapper.hasExtendedNametableMapping
        if let safePPUState = aState
        {
            self.cycle = Int(safePPUState.cycle)
            self.frame = safePPUState.frame
            self.paletteData = safePPUState.paletteData
            self.nameTableData = safePPUState.nameTableData
            self.oamData = safePPUState.oamData
            self.v = safePPUState.v
            self.t = safePPUState.t
            self.x = safePPUState.x
            self.w = safePPUState.w
            self.f = safePPUState.f
            self.register = safePPUState.register
            self.nmiOccurred = safePPUState.nmiOccurred
            self.nmiOutput = safePPUState.nmiOutput
            self.nmiDelay = safePPUState.nmiDelay
            self.nameTableByte = safePPUState.nameTableByte
            self.attributeTableByte = safePPUState.attributeTableByte
            self.lowTileByte = safePPUState.lowTileByte
            self.highTileByte = safePPUState.highTileByte
            self.tileData = safePPUState.tileData
            self.spriteCount = Int(safePPUState.spriteCount)
            self.spritePatterns = safePPUState.spritePatterns
            self.spritePositions = safePPUState.spritePositions
            self.spritePriorities = safePPUState.spritePriorities
            self.spriteIndexes = safePPUState.spriteIndexes
            self.flagNameTable = safePPUState.flagNameTable
            self.flagIncrement = safePPUState.flagIncrement
            self.flagSpriteTable = safePPUState.flagSpriteTable
            self.flagBackgroundTable = safePPUState.flagBackgroundTable
            self.flagSpriteSize = safePPUState.flagSpriteSize
            self.flagMasterSlave = safePPUState.flagMasterSlave
            self.flagGrayscale = safePPUState.flagGrayscale
            self.flagShowLeftBackground = safePPUState.flagShowLeftBackground
            self.flagShowLeftSprites = safePPUState.flagShowLeftSprites
            self.flagShowBackground = safePPUState.flagShowBackground
            self.flagShowSprites = safePPUState.flagShowSprites
            self.flagRedTint = safePPUState.flagRedTint
            self.flagGreenTint = safePPUState.flagGreenTint
            self.flagBlueTint = safePPUState.flagBlueTint
            self.flagSpriteZeroHit = safePPUState.flagSpriteZeroHit
            self.flagSpriteOverflow = safePPUState.flagSpriteOverflow
            self.oamAddress = safePPUState.oamAddress
            self.bufferedData = safePPUState.bufferedData
            self.frontBuffer = safePPUState.frontBuffer
            self.scanline = Int(safePPUState.scanline)
        }
    }
    
    var ppuState: PPUState
    {
        return PPUState.init(cycle: UInt16(self.cycle), scanline: UInt16(self.scanline), frame: self.frame, paletteData: self.paletteData, nameTableData: self.nameTableData, oamData: self.oamData, v: self.v, t: self.t, x: self.x, w: self.w, f: self.f, register: self.register, nmiOccurred: self.nmiOccurred, nmiOutput: self.nmiOutput, nmiPrevious: false, nmiDelay: self.nmiDelay, nameTableByte: self.nameTableByte, attributeTableByte: self.attributeTableByte, lowTileByte: self.lowTileByte, highTileByte: self.highTileByte, tileData: self.tileData, spriteCount: UInt8(self.spriteCount), spritePatterns: self.spritePatterns, spritePositions: self.spritePositions, spritePriorities: self.spritePriorities, spriteIndexes: self.spriteIndexes, flagNameTable: self.flagNameTable, flagIncrement: self.flagIncrement, flagSpriteTable: self.flagSpriteTable, flagBackgroundTable: self.flagBackgroundTable, flagSpriteSize: self.flagSpriteSize, flagMasterSlave: self.flagMasterSlave, flagGrayscale: self.flagGrayscale, flagShowLeftBackground: self.flagShowLeftBackground, flagShowLeftSprites: self.flagShowLeftSprites, flagShowBackground: self.flagShowBackground, flagShowSprites: self.flagShowSprites, flagRedTint: self.flagRedTint, flagGreenTint: self.flagGreenTint, flagBlueTint: self.flagBlueTint, flagSpriteZeroHit: self.flagSpriteZeroHit, flagSpriteOverflow: self.flagSpriteOverflow, oamAddress: self.oamAddress, bufferedData: self.bufferedData, frontBuffer: self.frontBuffer)
    }
    
    mutating func read(address aAddress: UInt16) -> UInt8
    {
        let address: UInt16 = aAddress & 0x3FFF
        if address < 0x2000 // 0x0000 ... 0x1FFF
        {
            return self.mapper.ppuRead(address: address)
        }
        else if address < 0x3000 // 0x2000 ... 0x2FFF
        {
            if self.mapperHasExtendedNametableMapping
            {
                return self.mapper.ppuRead(address: aAddress)
            }
            else
            {
                return self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode))]
            }
        }
        else if address < 0x3F00 // 0x3000 ... 0x3EFF
        {
            return self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode))]
        }
        else // 0x3F00 ... 0x3FFF
        {
            return self.readPalette(address: address & 0x1F)
        }
    }
    
    mutating func write(address aAddress: UInt16, value aValue: UInt8)
    {
        let address: UInt16 = aAddress & 0x3FFF

        if address < 0x2000 // 0x0000 ... 0x1FFF
        {
            self.mapper.ppuWrite(address: address, value: aValue)
        }
        else if address < 0x3000 // 0x2000 ... 0x2FFF
        {
            if self.mapperHasExtendedNametableMapping
            {
                self.mapper.ppuWrite(address: address, value: aValue)
            }
            else
            {
                self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode))] = aValue
            }
        }
        else if address < 0x3F00 // 0x3000 ... 0x3EFF
        {
            self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode))] = aValue
        }
        else // 0x3F00 ... 0x3FFF
        {
            self.writePalette(address: address & 0x001F, value: aValue)
        }
    }
    
    @inline (__always)
    private func adjustedPPUAddress(forOriginalAddress aOriginalAddress: UInt16, withMirroringMode aMirrorMode: MirroringMode) -> UInt16
    {
        let address: UInt16 = aOriginalAddress & 0x0FFF
        let addrRange: UInt16 = address &>> 10
        let offset: UInt16 = address & 0x03FF
        return (PPU.nameTableOffsetSequence[aMirrorMode.rawValue][Int(addrRange)] | offset) & 0x07FF // limit to 2KB range (0x0800)
    }
    
    mutating func reset()
    {
        self.cycle = 340
        self.scanline = 240
        self.frame = 0
        self.writeControl(value: 0)
        self.writeMask(value: 0)
        self.writeOAMAddress(value: 0)
        self.backBuffer = PPU.emptyBuffer
        self.frontBuffer = PPU.emptyBuffer
    }
    
    @inline (__always)
    private mutating func readPalette(address aAddress: UInt16) -> UInt8 // mutating because it makes a copy of PPU otherwise
    {
        let index: UInt16 = (aAddress >= 16 && aAddress % 4 == 0) ? aAddress - 16 : aAddress
        return self.paletteData[Int(index)]
    }

    @inline (__always)
    private mutating func writePalette(address aAddress: UInt16, value aValue: UInt8)
    {
        let index: UInt16 = (aAddress >= 16 && aAddress % 4 == 0) ? aAddress - 16 : aAddress
        self.paletteData[Int(index)] = aValue
    }

    mutating func readRegister(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x2002:
            return self.readStatus()
        case 0x2004:
            return self.readOAMData()
        case 0x2007:
            return self.readData()
        default: return 0
        }
    }

    mutating func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        self.register = aValue
        switch aAddress
        {
        case 0x2000:
            self.writeControl(value: aValue)
        case 0x2001:
            self.writeMask(value: aValue)
        case 0x2003:
            self.writeOAMAddress(value: aValue)
        case 0x2004:
            self.writeOAMData(value: aValue)
        case 0x2005:
            self.writeScroll(value: aValue)
        case 0x2006:
            self.writeAddress(value: aValue)
        case 0x2007:
            self.writeData(value: aValue)
        case 0x4014:
            // Write DMA (this is actually handled elsewhere when the CPU calls the PPU's writeOAMData function)
            break
        default: break
        }
    }

    // $2000: PPUCTRL
    @inline (__always)
    private mutating func writeControl(value aValue: UInt8)
    {
        self.flagNameTable = (aValue >> 0) & 3
        self.flagIncrement = ((aValue >> 2) & 1) == 1
        self.flagSpriteTable = ((aValue >> 3) & 1) == 1
        self.flagBackgroundTable = ((aValue >> 4) & 1) == 1
        self.flagSpriteSize = ((aValue >> 5) & 1) == 1
        self.flagMasterSlave = ((aValue >> 6) & 1) == 1
        self.nmiOutput = ((aValue >> 7) & 1) == 1
        // TODO: should we set NMI Delay (self.nmiDelay) here if self.nmiOutput is true?
        // t: ....BA.. ........ = d: ......BA
        self.t = (self.t & 0xF3FF) | ((UInt16(aValue) & 0x03) << 10)
    }

    // $2001: PPUMASK
    @inline (__always)
    private mutating func writeMask(value aValue: UInt8)
    {
        self.flagGrayscale = ((aValue >> 0) & 1) == 1
        self.flagShowLeftBackground = ((aValue >> 1) & 1) == 1
        self.flagShowLeftSprites = ((aValue >> 2) & 1) == 1
        self.flagShowBackground = ((aValue >> 3) & 1) == 1
        self.flagShowSprites = ((aValue >> 4) & 1) == 1
        self.flagRedTint = ((aValue >> 5) & 1) == 1
        self.flagGreenTint = ((aValue >> 6) & 1) == 1
        self.flagBlueTint = ((aValue >> 7) & 1) == 1
    }
    
    // $2002: PPUSTATUS
    @inline (__always)
    private mutating func readStatus() -> UInt8
    {
        var result = self.register & 0x1F
        result |= self.flagSpriteOverflow << 5
        result |= self.flagSpriteZeroHit << 6
        if self.nmiOccurred
        {
            result |= 1 << 7
        }
        self.nmiOccurred = false
        // w:                   = 0
        self.w = false
        return result
    }

    // $2003: OAMADDR
    @inline (__always)
    private mutating func writeOAMAddress(value aValue: UInt8)
    {
        self.oamAddress = aValue
    }

    // $2004: OAMDATA (read)
    @inline (__always)
    private mutating func readOAMData() -> UInt8
    {
        let result: UInt8
        if (self.oamAddress & 0x03) == 0x02 // if sprite byte 2 of 0...3
        {
            // bits 2...4 should always come back as zero
            // (see http://wiki.nesdev.com/w/index.php/PPU_OAM )
            result = self.oamData[Int(self.oamAddress)] & 0xE3
        }
        else
        {
            result = self.oamData[Int(self.oamAddress)]
        }
        
        return result
    }

    // $2004: OAMDATA (write)
    @inline (__always)
    private mutating func writeOAMData(value aValue: UInt8)
    {
        self.oamData[Int(self.oamAddress)] = aValue
        self.oamAddress &+= 1
    }

    // $2005: PPUSCROLL
    @inline (__always)
    private mutating func writeScroll(value aValue: UInt8)
    {
        if self.w == false
        {
            // t: ........ ...HGFED = d: HGFED...
            // x:               CBA = d: .....CBA
            // w:                   = 1
            self.t = (self.t & 0xFFE0) | (UInt16(aValue) >> 3)
            self.x = aValue & 0x07
            self.w = true
        }
        else
        {
            // t: .CBA..HG FED..... = d: HGFEDCBA
            // w:                   = 0
            self.t = (self.t & 0x8FFF) | ((UInt16(aValue) & 0x07) << 12)
            self.t = (self.t & 0xFC1F) | ((UInt16(aValue) & 0xF8) << 2)
            self.w = false
        }
    }

    // $2006: PPUADDR
    private mutating func writeAddress(value aValue: UInt8)
    {
        if self.w == false {
            // t: ..FEDCBA ........ = d: ..FEDCBA
            // t: .X...... ........ = 0
            // w:                   = 1
            self.t = (self.t & 0x80FF) | ((UInt16(aValue) & 0x3F) << 8)
            self.w = true
        }
        else
        {
            // t: ........ HGFEDCBA = d: HGFEDCBA
            // v                    = t
            // w:                   = 0
            self.t = (self.t & 0xFF00) | UInt16(aValue)
            self.v = self.t
            self.w = false
        }
    }

    // $2007: PPUDATA (read)
    private mutating func readData() -> UInt8
    {
        var value = self.read(address: self.v)
        
        // emulate buffered reads
        if self.v % 0x4000 < 0x3F00
        {
            let buffered = self.bufferedData
            self.bufferedData = value
            value = buffered
        }
        else
        {
            self.bufferedData = self.read(address: self.v - 0x1000)
        }
        
        self.v &+= self.flagIncrement ? 32 : 1
        return value
    }

    // $2007: PPUDATA (write)
    private mutating func writeData(value aValue: UInt8)
    {
        self.write(address: self.v, value: aValue)
        self.v &+= self.flagIncrement ? 32 : 1
    }

    // $4014: OAMDMA
    
    /// called by the CPU with 256 bytes of OAM data for sprites and metadata
    mutating func writeOAMDMA(oamDMA aOamData: [UInt8])
    {
        var newOAMData = aOamData
        let remaining: Int = 256 - Int(self.oamAddress)
        memcpy(&self.oamData[Int(self.oamAddress)], &newOAMData, remaining)
        memcpy(&self.oamData, &newOAMData[remaining - 1], 256 - remaining)
    }
    

    private mutating func fetchSpritePattern(oamDataOffset aOamDataOffset: Int, attributes aAttributes: UInt8, row aRow: Int) -> UInt32
    {
        let tile: UInt16 = UInt16(self.oamData[aOamDataOffset &+ 1])
        let address: UInt16
        let tableOffset: UInt16
        let tileOffset: UInt16
        let rowOffset: UInt16
        if !self.flagSpriteSize
        {
            rowOffset = aAttributes & 0x80 == 0x80 ? UInt16(7 &- aRow) : UInt16(aRow)
            tableOffset = self.flagSpriteTable ? 0x1000 : 0
            tileOffset = tile &* 16
            address = tableOffset &+ tileOffset &+ rowOffset
        }
        else
        {
            let r: Int = aAttributes & 0x80 == 0x80 ? 15 &- aRow : aRow

            if r > 7
            {
                tileOffset = ((tile & 0xFE) &+ 1) &* 16
                rowOffset =  UInt16(r &- 8)
            }
            else
            {
                tileOffset = (tile & 0xFE) &* 16
                rowOffset = UInt16(r)
            }
            
            tableOffset = (tile & 1) &* 0x1000
            address = tableOffset &+ tileOffset &+ rowOffset
        }
        
        let a = (aAttributes & 3) &<< 2
        var lowTileByte = self.read(address: address)
        var highTileByte = self.read(address: address &+ 8)
        var data: UInt32 = 0
        var i: Int = 0
        while i < 8
        {
            let p1: UInt8
            let p2: UInt8
            if aAttributes & 0x40 == 0x40
            {
                p1 = (lowTileByte & 1) &<< 0
                p2 = (highTileByte & 1) &<< 1
                lowTileByte &>>= 1
                highTileByte &>>= 1
            }
            else
            {
                p1 = (lowTileByte & 0x80) &>> 7
                p2 = (highTileByte & 0x80) &>> 6
                lowTileByte &<<= 1
                highTileByte &<<= 1
            }
            data &<<= 4
            data |= UInt32(a | p1 | p2)
            i &+= 1
        }
        
        return data
    }

    private mutating func evaluateSprites()
    {
        let h: Int = self.flagSpriteSize ? 16 : 8
        var count: Int = 0
        var i: Int = 0
        while i < 64
        {
            let i4: Int = i &* 4
            let y = self.oamData[i4 &+ 0]
            let a = self.oamData[i4 &+ 2]
            let x = self.oamData[i4 &+ 3]
            let row = self.scanline &- Int(y)
            
            if row >= 0 && row < h
            {
                if count < 8
                {
                    self.spritePatterns[count] = self.fetchSpritePattern(oamDataOffset: i4, attributes: a, row: row)
                    self.spritePositions[count] = x
                    self.spritePriorities[count] = (a &>> 5) & 1
                    self.spriteIndexes[count] = UInt8(i)
                }
                
                count &+= 1
            }
            
            i &+= 1
        }
        
        if count > 8
        {
            count = 8
            self.flagSpriteOverflow = 1
        }
        
        self.spriteCount = count
    }
    
    /// executes a single PPU cycle, and returns a Boolean indicating whether the CPU should trigger an NMI based on this cycle
    mutating func step() -> PPUStepResults
    {
        var shouldTriggerNMI: Bool = false
        
        if self.nmiDelay > 0
        {
            self.nmiDelay &-= 1
            if self.nmiDelay == 0 && self.nmiOutput && self.nmiOccurred
            {
                shouldTriggerNMI = true
            }
        }
        
        let renderingEnabled: Bool = self.flagShowBackground || self.flagShowSprites
        
        // tick
        if self.cycle == 339 && self.scanline == 261 && renderingEnabled && self.f
        {
            self.cycle = 0
            self.scanline = 0
            self.frame &+= 1
            self.f = false
        }
        else
        {
            self.cycle &+= 1
            if self.cycle > 340
            {
                self.cycle = 0
                self.scanline &+= 1
                
                if self.scanline > 261
                {
                    self.scanline = 0
                    self.frame &+= 1
                    self.f.toggle()
                }
            }
        }
        
        let preLine: Bool = self.scanline == 261
        
        if renderingEnabled
        {
            let visibleCycle: Bool = self.cycle >= 1 && self.cycle <= 256
            let preFetchCycle: Bool = self.cycle >= 321 && self.cycle <= 336
            let fetchCycle: Bool = preFetchCycle || visibleCycle
            
            let visibleLine: Bool = self.scanline < 240
            let renderLine: Bool = preLine || visibleLine
            let safeAreaScanline: Bool = self.scanline >= 8 && self.scanline < 232
            
            // background logic
            if safeAreaScanline && visibleCycle
            {
                // render pixel
                let x = self.cycle &- 1
                let y = self.scanline &- 8
                let backgroundPixel: UInt8
                let spritePixelIndex: UInt8
                let spritePixel: UInt8
                let leftEdge = x < 8
                
                if leftEdge && !self.flagShowBackground
                {
                    backgroundPixel = 0
                }
                else
                {
                    let data = UInt32(self.tileData &>> 32) &>> ((7 &- self.x) &* 4)
                    backgroundPixel = UInt8(data & 0x0F)
                }
                
                if self.flagShowSprites
                {
                    let lastCycle = self.cycle &- 1
                    var sp: UInt8 = 0
                    var spi: UInt8 = 0
                    
                    var i: Int = 0
                    while i < self.spriteCount
                    {
                        let offset = lastCycle - Int(self.spritePositions[i])
                        if offset >= 0 && offset < 8
                        {
                            let color = UInt8((self.spritePatterns[i] >> UInt8((7 &- offset) &* 4)) & 0x0F)
                            if color % 4 != 0
                            {
                                sp = color
                                spi = UInt8(i)
                                break
                            }
                        }
                        i &+= 1
                    }
                    
                    spritePixel = leftEdge && !self.flagShowLeftSprites ? 0 : sp
                    spritePixelIndex = spi
                }
                else
                {
                    spritePixelIndex = 0
                    spritePixel = 0
                }
                
                let b: Bool = backgroundPixel % 4 != 0
                let s: Bool = spritePixel % 4 != 0
                let color: UInt8
                
                if !b
                {
                    color = s ? (spritePixel | 0x10) : 0
                }
                else if !s
                {
                    color = backgroundPixel
                }
                else
                {
                    let spi: Int = Int(spritePixelIndex)
                    
                    if self.spriteIndexes[spi] == 0 && x < 255
                    {
                        self.flagSpriteZeroHit = 1
                    }
                    
                    if self.spritePriorities[spi] == 0
                    {
                        color = spritePixel | 0x10
                    }
                    else
                    {
                        color = backgroundPixel
                    }
                }
                
                let paletteAddress: UInt16 = UInt16(color)
                let paletteAddressIndex: Int = Int((paletteAddress >= 16 && paletteAddress % 4 == 0) ? paletteAddress &- 16 : paletteAddress)
                let paletteColorsIndex: Int = Int(self.paletteData[paletteAddressIndex] & 0x3F)
                let paletteColor: UInt32 = PPU.paletteColors[paletteColorsIndex]
                self.backBuffer[(256 &* y) &+ x] = paletteColor
            }

            if renderLine && fetchCycle
            {
                self.tileData &<<= 4
                switch self.cycle & 0x07
                {
                case 1:
                    // fetch nametable byte
                    let v = self.v
                    let address = 0x2000 | (v & 0x0FFF)
                    self.nameTableByte = self.read(address: address)
                case 3:
                    // fetch attribute table byte
                    let v = self.v
                    let address = 0x23C0 | (v & 0x0C00) | ((v &>> 4) & 0x38) | ((v &>> 2) & 0x07)
                    let shift = ((v &>> 4) & 4) | (v & 2)
                    self.attributeTableByte = ((self.read(address: address) &>> shift) & 3) &<< 2
                case 5:
                    // fetch low tile byte
                    let fineY = (self.v &>> 12) & 7
                    let table: UInt16 = self.flagBackgroundTable ? 0x1000 : 0
                    let tile = self.nameTableByte
                    let address = table &+ (UInt16(tile) &* 16) &+ fineY
                    self.lowTileByte = self.read(address: address)
                case 7:
                    // fetch high tile byte
                    let fineY = (self.v &>> 12) & 7
                    let table: UInt16 = self.flagBackgroundTable ? 0x1000 : 0
                    let tile = self.nameTableByte
                    let address = table &+ (UInt16(tile) &* 16) &+ fineY
                    self.highTileByte = self.read(address: address &+ 8)
                case 0:
                    // store tile data
                    let a = self.attributeTableByte
                    var data: UInt32 = 0
                    var i: Int = 0
                    while i < 8
                    {
                        let p1: UInt8 = (self.lowTileByte & 0x80) &>> 7
                        let p2: UInt8 = (self.highTileByte & 0x80) &>> 6
                        self.lowTileByte &<<= 1
                        self.highTileByte &<<= 1
                        data &<<= 4
                        data |= UInt32(a | p1 | p2)
                        i &+= 1
                    }
                    self.tileData |= UInt64(data)
                default: break
                }
            }

            if preLine && self.cycle >= 280 && self.cycle <= 304
            {
                // copy Y
                // vert(v) = vert(t)
                // v: .IHGF.ED CBA..... = t: .IHGF.ED CBA.....
                self.v = (self.v & 0x841F) | (self.t & 0x7BE0)
            }

            if renderLine
            {
                if fetchCycle && self.cycle % 8 == 0
                {
                    // increment X
                    // increment hori(v)
                    // if coarse X == 31
                    if self.v & 0x001F == 31
                    {
                        // coarse X = 0
                        self.v &= 0xFFE0
                        // switch horizontal nametable
                        self.v ^= 0x0400
                    }
                    else
                    {
                        // increment coarse X
                        self.v &+= 1
                    }
                }

                if self.cycle == 256
                {
                    // Increment Y
                    // increment vert(v)
                    // if fine Y < 7
                    if self.v & 0x7000 != 0x7000
                    {
                        // increment fine Y
                        self.v &+= 0x1000
                    }
                    else
                    {
                        // fine Y = 0
                        self.v &= 0x8FFF
                        // let y = coarse Y
                        var y = (self.v & 0x03E0) >> 5
                        if y == 29
                        {
                            // coarse Y = 0
                            y = 0
                            // switch vertical nametable
                            self.v ^= 0x0800
                        }
                        else if y == 31
                        {
                            // coarse Y = 0, nametable not switched
                            y = 0
                        }
                        else
                        {
                            // increment coarse Y
                            y &+= 1
                        }
                        // put coarse Y back into v
                        self.v = (self.v & 0xFC1F) | (y << 5)
                    }
                }
                else if self.cycle == 257
                {
                    // copy X
                    // hori(v) = hori(t)
                    // v: .....F.. ...EDCBA = t: .....F.. ...EDCBA
                    self.v = (self.v & 0xFBE0) | (self.t & 0x041F)
                }
            }
            
            // sprite logic
            if self.cycle == 257
            {
                if visibleLine
                {
                    self.evaluateSprites()
                }
                else
                {
                    self.spriteCount = 0
                }
            }
        }

        // vblank logic
        if self.cycle == 1
        {
            if self.scanline == 241
            {
                // set vertical blank
                swap(&self.frontBuffer, &self.backBuffer)
                self.nmiOccurred = true
            }
            else if preLine
            {
                // clear vertical blank
                self.nmiOccurred = false
                self.flagSpriteZeroHit = 0
                self.flagSpriteOverflow = 0
            }
        }
        
        let results: PPUStepResults
        
        if self.mapperHasStep
        {
            let interruptRequestedByMapper: Interrupt? = self.mapper.step(input: MapperStepInput(ppuScanline: self.scanline, ppuCycle: self.cycle, ppuShowBackground: self.flagShowBackground, ppuShowSprites: flagShowSprites, ppuSpriteSize: self.flagSpriteSize))?.requestedCPUInterrupt
            results = PPUStepResults(requestedCPUInterrupt: interruptRequestedByMapper ?? (shouldTriggerNMI ? .nmi : nil))
        }
        else
        {
            results = PPUStepResults(requestedCPUInterrupt: shouldTriggerNMI ? .nmi : nil)
        }
        
        return results
    }
}
