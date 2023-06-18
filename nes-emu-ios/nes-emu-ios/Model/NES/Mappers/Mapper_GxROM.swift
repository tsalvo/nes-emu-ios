//
//  Mapper_GxROM.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 7/8/20.
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
import os

struct Mapper_GxROM: MapperProtocol
{
    let hasStep: Bool = false
    
    let hasExtendedNametableMapping: Bool = false
    
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var prgBank: Int
    private var chrBank: Int
    
    private let max32KBPrgBankIndex: UInt8
    private let max8KBChrBankIndex: UInt8
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var chrRom: [UInt8] = []
        var prgRom: [UInt8] = []
        
        for p in aCartridge.prgBlocks
        {
            prgRom.append(contentsOf: p)
        }
        
        for c in aCartridge.chrBlocks
        {
            chrRom.append(contentsOf: c)
        }
        
        self.prg = prgRom
        self.chr = chrRom
        
        let maxPrg32KBIndex: UInt8 = (UInt8(max(0, aCartridge.prgBlocks.count - 1)) / 2) & 0x03
        self.max8KBChrBankIndex = UInt8(max(0, aCartridge.chrBlocks.count - 1)) & 0x03
        self.max32KBPrgBankIndex = maxPrg32KBIndex
        
        self.mirroringMode = aCartridge.header.mirroringMode
        
        if let safeState = aState
        {
            self.chrBank = safeState.ints[safe: 1] ?? 0
            self.prgBank = safeState.ints[safe: 0] ?? Int(maxPrg32KBIndex)
        }
        else
        {
            self.chrBank = 0
            self.prgBank = Int(maxPrg32KBIndex)
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prgBank, self.chrBank], bools: [], uint8s: [], chr: [])
        }
        set
        {
            self.prgBank = newValue.ints[safe: 0] ?? 0
            self.chrBank = newValue.ints[safe: 1] ?? 0
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            return self.prg[(self.prgBank * 0x8000) + Int(aAddress - 0x8000)]
        case 0x6000 ... 0x7FFF:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_ColorDreams_GxROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            /*
             7  bit  0
             ---- ----
             xxPP xxCC
               ||   ||
               ||   ++- Select 8 KB CHR ROM bank for PPU $0000-$1FFF
               ++------ Select 32 KB PRG ROM bank for CPU $8000-$FFFF
             */
            self.prgBank = Int((aValue >> 4) & self.max32KBPrgBankIndex)
            self.chrBank = Int(aValue & self.max8KBChrBankIndex)
        case 0x6000 ... 0x7FFF:
            return self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_ColorDreams_GxROM CPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[(self.chrBank * 0x2000) + Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8)
    {
        os_log("unhandled Mapper_ColorDreams_GxROM PPU write at address: 0x%04X", aAddress)
    }

    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
