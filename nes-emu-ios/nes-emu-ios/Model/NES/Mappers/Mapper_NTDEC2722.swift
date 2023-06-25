//
//  Mapper_NTDEC2722.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 8/21/20.
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

struct Mapper_NTDEC2722: MapperProtocol
{
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = false
    
    private(set) var mirroringMode: MirroringMode
    
    private var prgBank: Int
    private var cycles: Int
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.prgBank = safeState.ints[safe: 0] ?? 0
            self.cycles = safeState.ints[safe: 1] ?? 0
            
            self.chr = safeState.chr
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.prgBank = 0
            self.cycles = 0
            
            for c in aCartridge.chrBlocks
            {
                self.chr.append(contentsOf: c)
            }
        }
        
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }
        
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
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prgBank, self.cycles], bools: [], uint8s: [], chr: self.chr)
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.prgBank = newValue.ints[safe: 0] ?? 0
            self.cycles = newValue.ints[safe: 1] ?? 0
            self.chr = newValue.chr
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x6000 ... 0x7FFF:
            return self.prg[Int(aAddress) - 0x6000 + (0x2000 * 6)]
        case 0x8000 ... 0x9FFF:
            return self.prg[Int(aAddress) - 0x8000 + (0x2000 * 4)]
        case 0xA000 ... 0xBFFF:
            return self.prg[Int(aAddress) - 0xa000 + (0x2000 * 5)]
        case 0xC000 ... 0xDFFF:
            return self.prg[Int(aAddress) - 0xc000 + (0x2000 * self.prgBank)]
        case 0xE000 ... 0xFFFF:
            return self.prg[Int(aAddress) - 0xe000 + (0x2000 * 7)]
        default:
            os_log("unhandled Mapper_NTDEC2722 read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0x9FFF:
            self.cycles = -1
        case 0xA000 ... 0xBFFF:
            self.cycles = 0
        case 0xE000 ... 0xFFFF:
            self.prgBank = Int(aValue)
        default:
            os_log("unhandled Mapper_NTDEC2722 write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        self.chr[Int(aAddress)] = aValue
    }

    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        guard self.cycles >= 0 else { return MapperStepResults(requestedCPUInterrupt: nil)  }
        
        let shouldIRQ: Bool
        self.cycles += 1
        if self.cycles % (4096 * 3) == 0
        {
            self.cycles = 0
            shouldIRQ = true
        }
        else
        {
            shouldIRQ = false
        }
        
        return MapperStepResults(requestedCPUInterrupt: shouldIRQ ? .irq : nil)
    }
}
