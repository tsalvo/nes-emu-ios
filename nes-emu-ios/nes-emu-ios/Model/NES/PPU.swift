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

protocol PPUProtocol: MemoryProtocol
{
    var frame: UInt64 { get }
    var cycle: Int { get }
    var scanline: Int { get }
    var frontBuffer: [UInt32] { get }
    var flagShowBackground: Bool { get }
    var flagShowSprites: Bool { get }
    func step() -> PPUStepResults
    func writeOAMDMA(oamDMA aOamData: [UInt8])
    func readRegister(address aAddress: UInt16) -> UInt8
    func writeRegister(address aAddress: UInt16, value aValue: UInt8)
}

struct PPUStepResults
{
    let shouldTriggerNMIOnCPU: Bool
    let shouldTriggerIRQOnCPU: Bool
}

/// NES Picture Processing Unit
class PPU: PPUProtocol
{
    private(set) var cycle: Int = 340
    private(set) var frame: UInt64 = 0
    
    /// an optimization to prevent unnecessary Mapper object type lookups and mapper step calls during frequent PPU.step() calls
    private let mapperHasStep: Bool
    
    private let mapper: MapperProtocol
    private var paletteData: [UInt8] = [UInt8].init(repeating: 0, count: 32)
    private var nameTableData: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    private var oamData: [UInt8] = [UInt8].init(repeating: 0, count: 256)
    
    /// for each mirroring mode, return nametable offset sequence
    private static let nameTableOffsetSequence: [[UInt16]] = [
        [0, 0, 1024, 1024],
        [0, 1024, 0, 1024],
        [0, 0, 0, 0],
        [1024, 1024, 1024, 1024],
        [0, 1024, 2048, 3072]
    ]
    
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
    private var nmiOccurred: Bool = false
    private var nmiOutput: Bool = false
    private var nmiPrevious: Bool = false
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
    
    static let emptyBuffer: [UInt32] = [UInt32].init(repeating: 0, count: 256 * 224)
    
    /// colors in 0xBBGGRRAA format from Palette.colors
    private(set) var frontBuffer: [UInt32] = PPU.emptyBuffer
    /// colors in 0xBBGGRRAA format from Palette.colors
    private var backBuffer: [UInt32] = PPU.emptyBuffer
    private(set) var scanline: Int = 240
    
    init(mapper aMapper: MapperProtocol)
    {
        self.mapper = aMapper
        self.mapperHasStep = aMapper.hasStep
    }
    
    func read(address aAddress: UInt16) -> UInt8
    {
        let address = aAddress % 0x4000
        switch address {
        case 0x0000 ..< 0x2000:
            return self.mapper.ppuRead(address: address)
        case 0x2000 ..< 0x3F00:
            return self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode) % 2048)]
        case 0x3F00 ..< 0x4000:
            return self.readPalette(address: (address % 32))
        default:
            return 0
        }
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        let address = aAddress % 0x4000
        switch address {
        case 0x0000 ..< 0x2000:
            self.mapper.ppuWrite(address: address, value: aValue)
        case 0x2000 ..< 0x3F00:
            self.nameTableData[Int(self.adjustedPPUAddress(forOriginalAddress: address, withMirroringMode: self.mapper.mirroringMode) % 2048)] = aValue
        case 0x3F00 ..< 0x4000:
            self.writePalette(address: (address % 32), value: aValue)
        default:
            break
        }
    }
    
    private func adjustedPPUAddress(forOriginalAddress aOriginalAddress: UInt16, withMirroringMode aMirrorMode: MirroringMode) -> UInt16
    {
        let address: UInt16 = (aOriginalAddress - 0x2000) % 0x1000
        let addrRange: UInt16 = address / 0x0400
        let offset: UInt16 = address % 0x0400
        return 0x2000 + PPU.nameTableOffsetSequence[Int(aMirrorMode.rawValue)][Int(addrRange)] + offset
    }
    
    func reset()
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
    
    func readPalette(address aAddress: UInt16) -> UInt8
    {
        let index: UInt16 = (aAddress >= 16 && aAddress % 4 == 0) ? aAddress - 16 : aAddress
        return self.paletteData[Int(index)]
    }

    private func writePalette(address aAddress: UInt16, value aValue: UInt8)
    {
        let index: UInt16 = (aAddress >= 16 && aAddress % 4 == 0) ? aAddress - 16 : aAddress
        self.paletteData[Int(index)] = aValue
    }

    func readRegister(address aAddress: UInt16) -> UInt8
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

    func writeRegister(address aAddress: UInt16, value aValue: UInt8)
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
    private func writeControl(value aValue: UInt8)
    {
        self.flagNameTable = (aValue >> 0) & 3
        self.flagIncrement = ((aValue >> 2) & 1) == 1
        self.flagSpriteTable = ((aValue >> 3) & 1) == 1
        self.flagBackgroundTable = ((aValue >> 4) & 1) == 1
        self.flagSpriteSize = ((aValue >> 5) & 1) == 1
        self.flagMasterSlave = ((aValue >> 6) & 1) == 1
        self.nmiOutput = ((aValue >> 7) & 1) == 1
        self.nmiChange()
        // t: ....BA.. ........ = d: ......BA
        self.t = (self.t & 0xF3FF) | ((UInt16(aValue) & 0x03) << 10)
    }

    // $2001: PPUMASK
    private func writeMask(value aValue: UInt8)
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
    private func readStatus() -> UInt8
    {
        var result = self.register & 0x1F
        result |= self.flagSpriteOverflow << 5
        result |= self.flagSpriteZeroHit << 6
        if self.nmiOccurred
        {
            result |= 1 << 7
        }
        self.nmiOccurred = false
        self.nmiChange()
        // w:                   = 0
        self.w = false
        return result
    }

    // $2003: OAMADDR
    private func writeOAMAddress(value aValue: UInt8)
    {
        self.oamAddress = aValue
    }

    // $2004: OAMDATA (read)
    private func readOAMData() -> UInt8
    {
        return self.oamData[Int(self.oamAddress)]
    }

    // $2004: OAMDATA (write)
    private func writeOAMData(value aValue: UInt8)
    {
        self.oamData[Int(self.oamAddress)] = aValue
        self.oamAddress &+= 1
    }

    // $2005: PPUSCROLL
    private func writeScroll(value aValue: UInt8)
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
    private func writeAddress(value aValue: UInt8)
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
    private func readData() -> UInt8
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
    private func writeData(value aValue: UInt8)
    {
        self.write(address: self.v, value: aValue)
        self.v &+= self.flagIncrement ? 32 : 1
    }

    // $4014: OAMDMA
    
    /// called by the CPU with 256 bytes of OAM data for sprites and metadata
    func writeOAMDMA(oamDMA aOamData: [UInt8])
    {
        for i in 0 ..< 256
        {
            self.oamData[Int(self.oamAddress)] = aOamData[i]
            self.oamAddress &+= 1
        }
    }
    
    // NTSC Timing Helper Functions

    private func incrementX()
    {
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

    private func incrementY()
    {
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

    private func copyX()
    {
        // hori(v) = hori(t)
        // v: .....F.. ...EDCBA = t: .....F.. ...EDCBA
        self.v = (self.v & 0xFBE0) | (self.t & 0x041F)
    }

    private func copyY()
    {
        // vert(v) = vert(t)
        // v: .IHGF.ED CBA..... = t: .IHGF.ED CBA.....
        self.v = (self.v & 0x841F) | (self.t & 0x7BE0)
    }

    private func nmiChange()
    {
        let nmi = self.nmiOutput && self.nmiOccurred
        if nmi && !self.nmiPrevious
        {
            // TODO: this fixes some games but the delay shouldn't have to be so
            // long, so the timings are off somewhere
            self.nmiDelay = 15
        }
        self.nmiPrevious = nmi
    }

    private func setVerticalBlank()
    {
        swap(&self.frontBuffer, &self.backBuffer)
        self.nmiOccurred = true
        self.nmiChange()
    }

    private func clearVerticalBlank()
    {
        self.nmiOccurred = false
        self.nmiChange()
    }

    private func fetchNameTableByte()
    {
        let v = self.v
        let address = 0x2000 | (v & 0x0FFF)
        self.nameTableByte = self.read(address: address)
    }

    private func fetchAttributeTableByte()
    {
        let v = self.v
        let address = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07)
        let shift = ((v >> 4) & 4) | (v & 2)
        self.attributeTableByte = ((self.read(address: address) >> shift) & 3) << 2
    }

    private func fetchLowTileByte()
    {
        let fineY = (self.v >> 12) & 7
        let table: UInt16 = self.flagBackgroundTable ? 0x1000 : 0
        let tile = self.nameTableByte
        let address = table + (UInt16(tile) * 16) + fineY
        self.lowTileByte = self.read(address: address)
    }

    private func fetchHighTileByte()
    {
        let fineY = (self.v >> 12) & 7
        let table: UInt16 = self.flagBackgroundTable ? 0x1000 : 0
        let tile = self.nameTableByte
        let address = table + (UInt16(tile) * 16) + fineY
        self.highTileByte = self.read(address: address + 8)
    }

    private func storeTileData()
    {
        var data: UInt32 = 0
        for _ in 0 ..< 8
        {
            let a = self.attributeTableByte
            let p1 = (self.lowTileByte & 0x80) >> 7
            let p2 = (self.highTileByte & 0x80) >> 6
            self.lowTileByte <<= 1
            self.highTileByte <<= 1
            data <<= 4
            data |= UInt32(a | p1 | p2)
        }
        self.tileData |= UInt64(data)
    }

    private func fetchTileData() -> UInt32
    {
        return UInt32(self.tileData >> 32)
    }

    private func backgroundPixel() -> UInt8
    {
        if !self.flagShowBackground
        {
            return 0
        }
        let data = self.fetchTileData() >> ((7 - self.x) * 4)
        return UInt8(data & 0x0F)
    }

    private func spritePixel() -> (UInt8, UInt8)
    {
        if !self.flagShowSprites
        {
            return (0, 0)
        }
        
        for i in 0 ..< self.spriteCount
        {
            var offset = (self.cycle - 1) - Int(self.spritePositions[i])
            if offset < 0 || offset > 7
            {
                continue
            }
            offset = 7 - offset
            let color = UInt8((self.spritePatterns[i] >> UInt8(offset * 4)) & 0x0F)
            if color % 4 == 0
            {
                continue
            }
            return (UInt8(i), color)
        }
        return (0, 0)
    }

    private func renderPixel()
    {
        let x = self.cycle - 1
        let y = self.scanline - 8
        var background = self.backgroundPixel()
        var spritePixelTuple: (i: UInt8, sprite: UInt8) = self.spritePixel()
        
        if x < 8
        {
            if !self.flagShowLeftBackground
            {
                background = 0
            }
            
            if !self.flagShowLeftSprites
            {
                spritePixelTuple.sprite = 0
            }
        }
        
        let b = background % 4 != 0
        let s = spritePixelTuple.sprite % 4 != 0
        var color: UInt8
        if !b && !s
        {
            color = 0
        }
        else if !b && s
        {
            color = spritePixelTuple.sprite | 0x10
        }
        else if b && !s
        {
            color = background
        }
        else
        {
            if self.spriteIndexes[Int(spritePixelTuple.i)] == 0 && x < 255
            {
                self.flagSpriteZeroHit = 1
            }
            
            if self.spritePriorities[Int(spritePixelTuple.i)] == 0
            {
                color = spritePixelTuple.sprite | 0x10
            }
            else
            {
                color = background
            }
        }
        
        let c = Palette.colors[Int(self.readPalette(address: UInt16(color)) % 64)]
        self.backBuffer[(256 * (223 - y)) + x] = c
    }

    private func fetchSpritePattern(i aI: Int, row aRow: Int) -> UInt32
    {
        var row = aRow
        var tile = self.oamData[(aI * 4) + 1]
        let attributes = self.oamData[(aI * 4) + 2]
        var address: UInt16
        
        if !self.flagSpriteSize
        {
            if attributes & 0x80 == 0x80
            {
                row = 7 - row
            }
            
            let table: UInt16 = self.flagSpriteTable ? 0x1000 : 0
            address = table + (UInt16(tile) * 16) + UInt16(row)
        }
        else
        {
            if attributes & 0x80 == 0x80
            {
                row = 15 - row
            }
            let table = tile & 1
            tile &= 0xFE
            if row > 7
            {
                tile &+= 1
                row &-= 8
            }
            address = 0x1000 * UInt16(table) + UInt16(tile) * 16 + UInt16(row)
        }
        
        let a = (attributes & 3) << 2
        var lowTileByte = self.read(address: address)
        var highTileByte = self.read(address: address + 8)
        var data: UInt32 = 0
        
        for _ in 0 ..< 8
        {
            var p1: UInt8
            var p2: UInt8
            if attributes & 0x40 == 0x40
            {
                p1 = (lowTileByte & 1) << 0
                p2 = (highTileByte & 1) << 1
                lowTileByte >>= 1
                highTileByte >>= 1
            }
            else
            {
                p1 = (lowTileByte & 0x80) >> 7
                p2 = (highTileByte & 0x80) >> 6
                lowTileByte <<= 1
                highTileByte <<= 1
            }
            data <<= 4
            data |= UInt32(a | p1 | p2)
        }
        
        return data
    }

    private func evaluateSprites()
    {
        let h: Int = self.flagSpriteSize ? 16 : 8
        var count: Int = 0
        
        for i in 0 ..< 64
        {
            let y = self.oamData[(i * 4) + 0]
            let a = self.oamData[(i * 4) + 2]
            let x = self.oamData[(i * 4) + 3]
            let row = self.scanline - Int(y)
            
            if row < 0 || row >= h
            {
                continue
            }
            
            if count < 8
            {
                self.spritePatterns[count] = self.fetchSpritePattern(i: i, row: row)
                self.spritePositions[count] = x
                self.spritePriorities[count] = (a >> 5) & 1
                self.spriteIndexes[count] = UInt8(i)
            }
            
            count += 1
        }
        
        if count > 8
        {
            count = 8
            self.flagSpriteOverflow = 1
        }
        
        self.spriteCount = count
    }

    /// Updates Cycle, ScanLine and Frame counters.
    private func tick()
    {
        if self.flagShowBackground || self.flagShowSprites
        {
            if self.f == true && self.scanline == 261 && self.cycle == 339
            {
                self.cycle = 0
                self.scanline = 0
                self.frame += 1
                self.f.toggle()
                return
            }
        }
        
        self.cycle += 1
        if self.cycle > 340
        {
            self.cycle = 0
            self.scanline += 1
            
            if self.scanline > 261
            {
                self.scanline = 0
                self.frame += 1
                self.f.toggle()
            }
        }
    }
    
    /// processes NMI delay timing and returns a Boolean indicating whether the CPU should trigger an NMI
    private func nmiCheck() -> Bool
    {
        var shouldTriggerNMIOnCPU: Bool = false
        if self.nmiDelay > 0
        {
            self.nmiDelay -= 1
            if self.nmiDelay == 0 && self.nmiOutput && self.nmiOccurred
            {
                shouldTriggerNMIOnCPU = true
            }
        }
        
        return shouldTriggerNMIOnCPU
    }

    /// executes a single PPU cycle, and returns a Boolean indicating whether the CPU should trigger an NMI based on this cycle
    func step() -> PPUStepResults
    {
        let shouldTriggerNMI: Bool = self.nmiCheck()
        self.tick()

        let renderingEnabled: Bool = self.flagShowBackground || self.flagShowSprites
        let preLine: Bool = self.scanline == 261
        let visibleLine: Bool = self.scanline < 240
        let safeAreaLine: Bool = self.scanline >= 8 && self.scanline < 232
        let renderLine: Bool = preLine || visibleLine
        let preFetchCycle: Bool = self.cycle >= 321 && self.cycle <= 336
        let visibleCycle: Bool = self.cycle >= 1 && self.cycle <= 256
        let fetchCycle: Bool = preFetchCycle || visibleCycle

        // background logic
        if renderingEnabled
        {
            if safeAreaLine && visibleCycle
            {
                self.renderPixel()
            }
            
            if renderLine && fetchCycle
            {
                self.tileData <<= 4
                switch self.cycle % 8
                {
                case 1:
                    self.fetchNameTableByte()
                case 3:
                    self.fetchAttributeTableByte()
                case 5:
                    self.fetchLowTileByte()
                case 7:
                    self.fetchHighTileByte()
                case 0:
                    self.storeTileData()
                default: break
                }
            }
            
            if preLine && self.cycle >= 280 && self.cycle <= 304
            {
                self.copyY()
            }
            
            if renderLine
            {
                if fetchCycle && self.cycle % 8 == 0
                {
                    self.incrementX()
                }
                
                if self.cycle == 256
                {
                    self.incrementY()
                }
                else if self.cycle == 257
                {
                    self.copyX()
                }
            }
        }

        // sprite logic
        if renderingEnabled
        {
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
        if self.scanline == 241 && self.cycle == 1
        {
            self.setVerticalBlank()
        }
        
        if preLine && self.cycle == 1
        {
            self.clearVerticalBlank()
            self.flagSpriteZeroHit = 0
            self.flagSpriteOverflow = 0
        }
        
        let shouldTriggerIRQ: Bool
        if self.mapperHasStep
        {
            shouldTriggerIRQ = self.mapper.step(input: MapperStepInput(ppuScanline: self.scanline, ppuCycle: self.cycle, ppuShowBackground: self.flagShowBackground, ppuShowSprites: flagShowSprites))?.shouldTriggerIRQOnCPU ?? false
        }
        else
        {
            shouldTriggerIRQ = false
        }
        
        return PPUStepResults(shouldTriggerNMIOnCPU: shouldTriggerNMI, shouldTriggerIRQOnCPU: shouldTriggerIRQ)
    }
}
