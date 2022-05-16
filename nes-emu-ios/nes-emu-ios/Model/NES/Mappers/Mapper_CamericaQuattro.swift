//
//  Mapper_CamericaQuattro.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 5/15/22.
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

struct Mapper_CamericaQuattro: MapperProtocol
{
    // MARK: - Internal Variables
    let hasStep: Bool = false
    let hasExtendedNametableMapping: Bool = false
    let mirroringMode: MirroringMode
    
    // MARK: - Private Variables
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]

    /// an offset within the PRG ROM, multiple of 64KB
    private var prg64KBBlockOffset: Int
    /// an offset within the current block, multiple of 16KB
    private var prg16KBPageOffset: Int

    /// 8KB of CHR RAM
    private var chrRam: [UInt8] = [UInt8](repeating: 0, count: 8192)
    
    // MARK: - Life Cycle
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks.prefix(16) // max 16 PRG blocks (256KB)
        {
            p.append(contentsOf: pBlock)
        }
        
        // pad to a multiple of 64KB for safety
        while p.count < 0x10000
        {
            p.append(contentsOf: [UInt8](repeating: 0, count: 0x4000))
        }
        
        self.prg = p
        
        if let safeState = aState,
           safeState.uint8s.count >= 8192,
           safeState.ints.count >= 2
        {
            self.prg16KBPageOffset = safeState.ints[0]
            self.prg64KBBlockOffset = safeState.ints[1]
            self.chrRam = [UInt8](safeState.uint8s[0 ..< 8192])
        }
        else
        {
            self.prg16KBPageOffset = 0
            self.prg64KBBlockOffset = max(0, (aCartridge.prgBlocks.count / 4) - 1) * 0x10000
        }
        
        self.mirroringMode = aCartridge.header.mirroringMode
    }
    
    // MARK: - Save State
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prg16KBPageOffset, self.prg64KBBlockOffset], bools: [], uint8s: self.chrRam, chr: [])
        }
        set
        {
            guard newValue.uint8s.count >= 8192,
                  newValue.ints.count >= 2 else { return }
            self.prg16KBPageOffset = newValue.ints[0]
            self.prg64KBBlockOffset = newValue.ints[1]
        }
    }
    
    // MARK: - CPU Handling
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
            /*
             Pages are taken from the 64k block currently selected by $8000.
              
                    $8000   $A000   $C000   $E000
                  +---------------+---------------+
                  |     $C000     |     { 3 }     |
                  +---------------+---------------+
             */
        case 0x8000 ... 0xBFFF: // The current 16KB Page within the selected 64KB block
            return self.prg[self.prg64KBBlockOffset + self.prg16KBPageOffset + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // last 16KB PRG ROM bank within current 64KB block
            return self.prg[self.prg64KBBlockOffset + (3 * 0x4000) + Int(aAddress - 0xC000)]
        case 0x6000 ... 0x7FFF:
            return 0 // No SRAM
        default:
            os_log("unhandled Mapper_CamericaQuattro read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x8000 ... 0xBFFF:
            // $8000-BFFF:   [...B B...]   PRG Block Select
            self.prg64KBBlockOffset = Int((aValue >> 3) & 0x03) * 0x10000
        case 0xC000 ... 0xFFFF:
            // $C000-FFFF:   [.... ..PP]   PRG Page Select
            self.prg16KBPageOffset = Int(aValue & 0x03) * 0x4000
        case 0x6000 ... 0x7FFF: // write to SRAM save
            break
        default:
            os_log("unhandled Mapper_CamericaQuattro write at address: 0x%04X", aAddress)
            break
        }
    }
    
    // MARK: - PPU Handling
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chrRam[Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        self.chrRam[Int(aAddress)] = aValue
    }
    
    // MARK: - Step
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
