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
    
    var mirroringMode: MirroringMode
    let availableMirroringModes: [MirroringMode]
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB CHR bank at $0000 ... $1FFF
    private var chrBank: Int
    
    /// 16KB PRG bank at $8000 ... $BFFF
    private var prgBank: Int
    
    private let fixedLastPrgBankIndex: Int
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState
        {
            self.mirroringMode = MirroringMode.init(rawValue: Int(safeState.mirroringMode)) ?? aCartridge.header.mirroringMode
            self.chrBank = safeState.ints[safe: 0] ?? 0
            self.prgBank = safeState.ints[safe: 1] ?? 0
            self.chr = safeState.chr
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode

            self.chrBank = 0
            self.prgBank = 0
            
            for c in aCartridge.chrBlocks
            {
                self.chr.append(contentsOf: c)
            }
        }
        
        switch aCartridge.header.mirroringMode {
        case .single0, .single1:
            self.availableMirroringModes = [MirroringMode.single0, MirroringMode.single1]
        default:
            self.availableMirroringModes = [MirroringMode.horizontal, MirroringMode.vertical]
        }
        
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }
        
        self.fixedLastPrgBankIndex = max(0, (aCartridge.prgBlocks.count - 1) * 16384)
        
        if self.chr.count == 0
        {
            // use a block for CHR RAM if no block exists
            self.chr.append(contentsOf: [UInt8].init(repeating: 0, count: 8192))
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: UInt8(self.mirroringMode.rawValue), ints: [self.chrBank], bools: [], uint8s: [], chr: self.chr)
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: Int(newValue.mirroringMode)) ?? self.mirroringMode
            self.chrBank = newValue.ints[safe: 0] ?? 0
            self.prgBank = newValue.ints[safe: 1] ?? 0
            self.chr = newValue.chr
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
            return self.prg[self.fixedLastPrgBankIndex + Int(aAddress - 0xC000)]
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
            self.prgBank = Int(aValue & 0x07)
            self.chrBank = Int((aValue >> 4) & 0x0F)
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
        self.chr[(self.chrBank * 0x2000) + Int(aAddress)] = aValue
    }
    
    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
