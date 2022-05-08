//
//  Mapper_CNROM.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/18/20.
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

struct Mapper_CNROM: MapperProtocol
{
    let hasStep: Bool = false
    let hasExtendedNametableMapping: Bool = false
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    /// Switchable 8KB CHR Bank
    private var chrBank: Int
    /// the number of 8KB CHR blocks in the ROM (up to 4)
    private let numChrBanks: Int
    /// 16KB PRG bank, fixed to first bank
    private let prgBank1: Int
    /// 16KB PRG bank, fixed to last bank
    private let prgBank2: Int
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState,
           safeState.ints.count >= 1
        {
            self.chrBank = safeState.ints[0]
        }
        else
        {
            self.chrBank = 0
        }
        
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks.prefix(2) // max 2 PRG blocks (32KB)
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks.prefix(4) // max 4 CHR blocks (32KB)
        {
            c.append(contentsOf: cBlock)
        }
        
        self.numChrBanks = c.count / 0x2000
        
        self.prg = p
        self.chr = c
        self.prgBank1 = 0
        self.prgBank2 = aCartridge.prgBlocks.count - 1
        self.mirroringMode = aCartridge.header.mirroringMode
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.chrBank], bools: [], uint8s: [], chr: [])
        }
        set
        {
            guard newValue.ints.count >= 1 else { return }
            self.chrBank = newValue.ints[0]
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xBFFF: // PRG Block 0
            return self.prg[self.prgBank1 * 0x4000 + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // PRG Block 1
            return self.prg[self.prgBank2 * 0x4000 + Int(aAddress - 0xC000)]
        case 0x6000 ... 0x7FFF: // No SRAM
            return 0
        default:
            os_log("unhandled Mapper_CNROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x8000 ... 0xFFFF:
            self.chrBank = Int(aValue & 0x03) % self.numChrBanks
        case 0x6000 ... 0x7FFF: // No SRAM
            break
        default:
            os_log("unhandled Mapper_CNROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[(self.chrBank * 0x2000) + Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        // CHR ROM only, no writing
    }
    
    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
