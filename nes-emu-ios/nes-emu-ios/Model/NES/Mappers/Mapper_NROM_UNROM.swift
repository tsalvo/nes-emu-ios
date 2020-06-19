//
//  Mapper_NROM_UNROM.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/18/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

class Mapper_NROM_UNROM: MapperProtocol
{
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var prgBanks: Int
    private var prgBank1: Int
    private var prgBank2: Int
    
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
        
        if aCartridge.prgBlocks.count == 1
        {
            // mirror first PRG block if necessary
            self.prg.append(contentsOf: aCartridge.prgBlocks[0])
        }
        
        self.prgBanks = self.prg.count / 0x4000
        self.prgBank1 = 0
        self.prgBank2 = self.prgBanks - 1
    }
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000: // CHR Block
            return self.chr[Int(aAddress)]
        case 0x8000 ..< 0xC000: // PRG Block 0
            return self.prg[self.prgBank1 * 0x4000 + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // PRG Block 1 (or mirror of PRG block 0 if only one PRG exists)
            return self.prg[self.prgBank2 * 0x4000 + Int(aAddress - 0xC000)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_NROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress {
        case 0x0000 ..< 0x2000: // CHR RAM?
            self.chr[Int(aAddress)] = aValue
        case 0x8000 ... 0xFFFF:
            self.prgBank1 = Int(aValue) % self.prgBanks
        case 0x6000 ..< 0x8000: // write to SRAM save
            self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_NROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func step(ppu aPPU: PPUProtocol?, cpu aCPU: CPUProtocol?)
    {
        
    }
}
