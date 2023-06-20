//
//  Mapper_78.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 4/30/22.
//  Copyright © 2022 Tom Salvo.
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

struct Mapper_78: MapperProtocol
{
    let hasStep: Bool = false
    
    let hasExtendedNametableMapping: Bool = false
    
    private(set) var mirroringMode: MirroringMode
    private let availableMirroringModes: [MirroringMode]
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    
    /// 8KB CHR bank at $0000 ... $1FFF
    private var chrBank: Int
    
    /// 16KB PRG bank at $8000 ... $BFFF
    private var prgBank: Int
    
    private let max16KBPrgBankOffset: Int
    private let max16KBPrgBankIndexU8: UInt8
    private let max8KBChrBankIndexU8: UInt8
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks
        {
            c.append(contentsOf: cBlock)
        }
        
        self.prg = p
        self.chr = c
        
        if let safeState = aState
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.chrBank = safeState.ints[safe: 0] ?? 0
            self.prgBank = safeState.ints[safe: 1] ?? 0
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.chrBank = 0
            self.prgBank = 0
        }
        
        switch aCartridge.header.mirroringMode {
        case .single0, .single1:
            self.availableMirroringModes = [MirroringMode.single0, MirroringMode.single1]
        default:
            self.availableMirroringModes = [MirroringMode.horizontal, MirroringMode.vertical]
        }
        
        self.max16KBPrgBankOffset = max(0, (aCartridge.prgBlocks.count - 1) * 16384)
        self.max16KBPrgBankIndexU8 = UInt8(max(0, aCartridge.chrBlocks.count - 1)) & 0x07
        self.max8KBChrBankIndexU8 = UInt8(max(0, aCartridge.chrBlocks.count - 1)) & 0x0F
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.chrBank, self.prgBank], bools: [], uint8s: [], chr: [])
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.chrBank = newValue.ints[safe: 0] ?? 0
            self.prgBank = newValue.ints[safe: 1] ?? 0
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
            // $8000 ... $BFFF
        case 0x8000 ... 0xBFFF:
            return self.prg[(self.prgBank * 0x4000) + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // last 16KB PRG bank
            return self.prg[self.max16KBPrgBankOffset + Int(aAddress - 0xC000)]
        default:
            os_log("unhandled Mapper_87 read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x8000 ... 0xFFFF:
            /*
             Bank Select
             7  bit  0
             ---- ----
             CCCC MPPP
             |||| ||||
             |||| |+++-- Select 16 KiB PRG ROM bank for CPU $8000-$BFFF
             |||| +----- Mirroring.  Holy Diver: 0 = H, 1 = V.  Cosmo Carrier: 0 = 1scA, 1 = 1scB.
             ++++------- Select 8KiB CHR ROM bank for PPU $0000-$1FFF
             */
            self.prgBank = Int(aValue & self.max16KBPrgBankIndexU8)
            self.chrBank = Int((aValue >> 4) & self.max8KBChrBankIndexU8)
            self.mirroringMode = self.availableMirroringModes[Int((aValue >> 3) & 1)]
        default:
            os_log("unhandled Mapper_87 write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[(self.chrBank * 0x2000) + Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        
    }
    
    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
