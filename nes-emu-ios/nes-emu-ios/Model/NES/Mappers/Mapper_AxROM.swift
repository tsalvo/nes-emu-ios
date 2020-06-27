//
//  Mapper_AxROM.swift
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

struct Mapper_AxROM: MapperProtocol
{
    let hasStep: Bool = false
    
    var mirroringMode: MirroringMode
    
    private var prgBank: Int = 0
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    init(withCartridge aCartridge: CartridgeProtocol)
    {
        self.mirroringMode = aCartridge.header.mirroringMode
        
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }

        for c in aCartridge.chrBlocks
        {
            self.chr.append(contentsOf: c)
        }

        if self.chr.count == 0
        {
            // use a block for CHR RAM if no block exists
            self.chr.append(contentsOf: [UInt8].init(repeating: 0, count: 8192))
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF: // PRG Blocks
            return self.prg[self.prgBank * 0x8000 + Int(aAddress - 0x8000)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_AxROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            self.prgBank = Int(aValue & 7)
            switch aValue & 0x10 {
            case 0x00:
                self.mirroringMode = .single0
            case 0x10:
                self.mirroringMode = .single1
            default: break
            }
        case 0x6000 ..< 0x8000:
            self.sram[Int(aAddress) - 0x6000] = aValue
        default:
            os_log("unhandled Mapper_AxROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        self.chr[Int(aAddress)] = aValue
    }

    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
