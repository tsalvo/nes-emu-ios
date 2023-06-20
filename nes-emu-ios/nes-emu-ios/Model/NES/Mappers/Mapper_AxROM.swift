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
    
    let hasExtendedNametableMapping: Bool = false
    
    var mirroringMode: MirroringMode
    
    private var prgBank: Int
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// 8KB of CHR RAM addressable though 0x0000 ... 0x1FFF
    private var chrRam: [UInt8]
    
    private let max32KBPrgBankIndex: UInt8
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState,
           safeState.uint8s.count >= 8192,
           safeState.ints.count >= 1
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.prgBank = safeState.ints[0]
            self.chrRam = [UInt8](safeState.uint8s[0 ..< 8192])
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.prgBank = 0
            self.chrRam = [UInt8].init(repeating: 0, count: 8192)
        }
        
        var p: [UInt8] = []
        for pBlock in aCartridge.prgBlocks
        {
            p.append(contentsOf: pBlock)
        }
        self.prg = p
        self.max32KBPrgBankIndex = aCartridge.prgBlocks.count > 1 ? (UInt8((aCartridge.prgBlocks.count / 2) - 1) & 0x0F) : 0
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prgBank], bools: [], uint8s: self.chrRam, chr: [])
        }
        set
        {
            guard newValue.uint8s.count >= 8192,
                  newValue.ints.count >= 1
            else {
                return
            }
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.prgBank = newValue.ints[0]
            self.chrRam = [UInt8](newValue.uint8s[0 ..< 8192])        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF: // PRG Blocks
            return self.prg[self.prgBank * 0x8000 + Int(aAddress - 0x8000)]
        case 0x6000 ..< 0x8000:
            return 0 // no SRAM
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
            self.prgBank = Int(aValue & self.max32KBPrgBankIndex)
            switch aValue & 0x10 {
            case 0x00:
                self.mirroringMode = .single0
            case 0x10:
                self.mirroringMode = .single1
            default: break
            }
        case 0x6000 ..< 0x8000:
            break // no SRAM
        default:
            os_log("unhandled Mapper_AxROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chrRam[Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        self.chrRam[Int(aAddress)] = aValue
    }

    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
