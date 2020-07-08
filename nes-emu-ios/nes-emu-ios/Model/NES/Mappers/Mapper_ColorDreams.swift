//
//  Mapper_ColorDreams.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 7/8/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

struct Mapper_ColorDreams: MapperProtocol
{
    let hasStep: Bool = false
    
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var prgBank: Int = 0
    private var chrBank: Int = 0
    
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
        
        self.prgBank = max(0, self.prg.count - 0x8000) / 0x8000
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
            os_log("unhandled Mapper_ColorDreams read at address: 0x%04X", aAddress)
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
             CCCC LLPP
             |||| ||||
             |||| ||++- Select 32 KB PRG ROM bank for CPU $8000-$FFFF
             |||| ++--- Used for lockout defeat
             ++++------ Select 8 KB CHR ROM bank for PPU $0000-$1FFF
             */
            self.chrBank = Int((aValue >> 4) & 0x0F)
            self.prgBank = Int(aValue & 0x03)
        case 0x6000 ... 0x7FFF:
            return self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_ColorDreams write at address: 0x%04X", aAddress)
            break
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return self.chr[(self.chrBank * 0x2000) + Int(aAddress)]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8)
    {
        self.chr[(self.chrBank * 0x2000) + Int(aAddress)] = aValue
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
