//
//  Mapper_87.swift
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

struct Mapper_87: MapperProtocol
{
    let hasStep: Bool = false
    
    let hasExtendedNametableMapping: Bool = false
    
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    
    private var chrBank: Int
    private let max8KBChrBankIndex: UInt8
    
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
        
        self.max8KBChrBankIndex = UInt8(max(0, aCartridge.chrBlocks.count - 1)) & 0x03
        
        if let safeState = aState,
           safeState.ints.count >= 1
        {
            self.mirroringMode = MirroringMode.init(rawValue: Int(safeState.mirroringMode)) ?? aCartridge.header.mirroringMode
            self.chrBank = safeState.ints[0]
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.chrBank = 0
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: UInt8(self.mirroringMode.rawValue), ints: [self.chrBank], bools: [], uint8s: [], chr: [])
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
        case 0x8000 ... 0xFFFF: // PRG
            return self.prg[Int(aAddress - 0x8000)]
        default:
            os_log("unhandled Mapper_87 read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x6000 ... 0x7FFF:
            /*
            $6000-7FFF:  [.... ..LH]
              H = High CHR Bit
              L = Low CHR Bit
          
            This reg selects 8k CHR @ $0000.  Note the reversed bit orders.  Most games using this mapper only have 16k CHR, so the 'H' bit is usually unused.
             */
            self.chrBank = Int(((aValue << 1) & 0b00000010) | ((aValue >> 1) & 0b00000001) & self.max8KBChrBankIndex)
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

