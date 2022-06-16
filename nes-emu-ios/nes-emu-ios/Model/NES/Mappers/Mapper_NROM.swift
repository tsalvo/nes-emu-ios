//
//  Mapper_NROM.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 5/8/22.
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

struct Mapper_NROM: MapperProtocol
{
    // MARK: - Constants
    private static let prgRamSizeInBytes: Int = 8192
    
    // MARK: - Internal Variables
    let hasStep: Bool = false
    let hasExtendedNametableMapping: Bool = false
    let mirroringMode: MirroringMode
    
    // MARK: - Private Variables
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    /// 16KB PRG bank, fixed to first bank
    private let prgBankOffset1: Int
    /// 16KB PRG bank, fixed to last bank, or mirror of first bank
    private let prgBankOffset2: Int
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF, 2KB or 4KB only used in Family Basic
    private var prgRam: [UInt8]
    
    // MARK: - Life Cycle
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState,
           safeState.uint8s.count >= Mapper_NROM.prgRamSizeInBytes
        {
            self.prgRam = [UInt8](safeState.uint8s[0 ..< Mapper_NROM.prgRamSizeInBytes])
        }
        else
        {
            self.prgRam = [UInt8](repeating: 0, count: Mapper_NROM.prgRamSizeInBytes)
        }
        
        self.mirroringMode = aCartridge.header.mirroringMode
        
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks.prefix(2) // max 2 PRG blocks (32KB)
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks.prefix(1) // max 1 CHR blocks (8KB)
        {
            c.append(contentsOf: cBlock)
        }
        
        if c.isEmpty
        {
            c = [UInt8](repeating: 0, count: 8192)
        }
        
        if p.isEmpty
        {
            p = [UInt8](repeating: 0, count: 16384)
        }
        
        self.chr = c
        self.prg = p
        
        self.prgBankOffset1 = 0
        self.prgBankOffset2 = (aCartridge.prgBlocks.count - 1) * 0x4000
    }
    
    // MARK: - Save State
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [], bools: [], uint8s: self.prgRam, chr: [])
        }
        set
        {
            guard newValue.uint8s.count >= Mapper_NROM.prgRamSizeInBytes else { return }
            self.prgRam = [UInt8](newValue.uint8s[0 ..< Mapper_NROM.prgRamSizeInBytes])
        }
    }
    
    // MARK: - CPU Handling
    mutating func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        if aAddress > 0xBFFF // 0xC000 ... 0xFFFF / PRG Block 1 (or mirror of PRG block 0 if only one PRG exists)
        {
            return self.prg[self.prgBankOffset2 + Int(aAddress - 0xC000)]
        }
        else if aAddress > 0x7FFF // 0x8000 ... 0xBFFF - PRG Block 0
        {
            return self.prg[self.prgBankOffset1 + Int(aAddress - 0x8000)]
        }
        else if aAddress > 0x5FFF // 0x6000 ... 0x7FFF - PRG RAM
        {
            return self.prgRam[Int(aAddress - 0x6000)]
        }
        else
        {
            os_log("unhandled Mapper_NROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x8000 ... 0xFFFF:
            // no registers, and no write to PRG ROM
            break
        case 0x6000 ... 0x7FFF: // write to SRAM save
            self.prgRam[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_NROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    // MARK: - PPU Handling
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        // CHR ROM only, no writing
    }
    
    // MARK: - Step
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
