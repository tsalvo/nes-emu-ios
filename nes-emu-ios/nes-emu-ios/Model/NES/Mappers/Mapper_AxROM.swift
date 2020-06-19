//
//  Mapper_AxROM.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/18/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

class Mapper_AxROM: MapperProtocol
{
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
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000: // CHR Block
            return self.chr[Int(aAddress)]
        case 0x8000 ... 0xFFFF: // PRG Blocks
            return self.prg[self.prgBank * 0x8000 + Int(aAddress - 0x8000)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_AxROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000:
            self.chr[Int(aAddress)] = aValue
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
    
    func step(ppu aPPU: PPUProtocol?, cpu aCPU: CPUProtocol?)
    {
        
    }
}
