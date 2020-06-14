//
//  Mapper.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/7/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

protocol MapperProtocol: class
{
    var mirroringMode: MirroringMode { get }
    func read(address aAddress: UInt16) -> UInt8
    func write(address aAddress: UInt16, value aValue: UInt8)
    func step()
}

class Mapper_UnsupportedPlaceholder: MapperProtocol
{
    init(withCartridge aCartridge: CartridgeProtocol)
    {
        self.mirroringMode = aCartridge.header.mirroringMode
    }
    
    let mirroringMode: MirroringMode
    
    func read(address aAddress: UInt16) -> UInt8
    {
        return 0
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8) { }
    
    func step() { }
}

class Mapper_NROM: MapperProtocol
{
    init(withCartridge aCartridge: CartridgeProtocol)
    {
        self.mirroringMode = aCartridge.header.mirroringMode
        switch aCartridge.prgBlocks.count
        {
        case 0:
            self.prgBlocks = [[UInt8]].init(repeating: [UInt8].init(repeating: 0, count: 16384), count: 2)
        case 1:
            self.prgBlocks = [aCartridge.prgBlocks[0], [UInt8].init(repeating: 0, count: 16384)]
        default:
            self.prgBlocks = [aCartridge.prgBlocks[0], aCartridge.prgBlocks[1]]
        }
        
        switch aCartridge.chrBlocks.count
        {
        case 0: self.chrBlock = [UInt8].init(repeating: 0, count: 8192)
        default: self.chrBlock = aCartridge.chrBlocks[0]
        }
        
        self.prgBanks = aCartridge.prgBlocks.count
        self.prgBank1 = 0
        self.prgBank2 = self.prgBanks - 1
    }
    
    deinit
    {
        print("DEINIT: \(self)")
    }

    let mirroringMode: MirroringMode
    private var prgBlocks: [[UInt8]]
    private var chrBlock: [UInt8]
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var prgBanks: Int
    private var prgBank1: Int
    private var prgBank2: Int
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000: // CHR Block
            return self.chrBlock[Int(aAddress)]
        case 0x8000 ..< 0xC000: // PRG Block 0
            return self.prgBlocks[0][Int(aAddress - 0x8000)]
        case 0xC000 ..< 0xFFFF: // PRG Block 1 (or mirror of PRG block 0 if only one PRG exists)
            let absoluteIndex = self.prgBank2 * 0x4000 + Int(aAddress - 0xC000)
            let prgBlockIndex = absoluteIndex / 0x4000
            let prgBankOffset = absoluteIndex % 0x4000
            return self.prgBlocks[prgBlockIndex][prgBankOffset]
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
            self.chrBlock[Int(aAddress)] = aValue
        
        case 0x8000 ... 0xFFFF:
            self.prgBank1 = Int(aValue) % self.prgBanks
        case 0x6000 ..< 0x8000: // write to SRAM save
            self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_NROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func step()
    {
        
    }
}

class Mapper_MMC1: MapperProtocol
{
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var shiftRegister: UInt8 = 0x10
    private var control: UInt8 = 0
    private var prgMode: UInt8 = 0
    private var chrMode: UInt8 = 0
    private var prgBank: UInt8 = 0
    private var chrBank0: UInt8 = 0
    private var chrBank1: UInt8 = 0
    private var prgOffsets: [Int] = [Int].init(repeating: 0, count: 2)
    private var chrOffsets: [Int] = [Int].init(repeating: 0, count: 2)
    
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
        
        self.prgOffsets[1] = self.prgBankOffset(index: -1)
    }
    
    deinit
    {
        print("DEINIT: \(self)")
    }
    
    func step()
    {
        
    }

    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000:
            let bank = aAddress / 0x1000
            let offset = aAddress % 0x1000
            let chrBaseOffset: Int = self.chrOffsets[Int(bank)]
            let chrFinalOffset: Int = chrBaseOffset + Int(offset)
            return self.chr[chrFinalOffset]
        case 0x8000 ... 0xFFFF:
            let adjustedAddress = aAddress - 0x8000
            let bank = adjustedAddress / 0x4000
            let offset = adjustedAddress % 0x4000
            return self.prg[self.prgOffsets[Int(bank)] + Int(offset)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_MMC1 read at address: 0x%04X", aAddress)
            return 0
        }
    }

    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000:
            let bank = aAddress / 0x1000
            let offset = aAddress % 0x1000
            self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
        case 0x8000 ... 0xFFFF:
            self.loadRegister(address: aAddress, value: aValue)
        case 0x6000 ..< 0x8000:
            self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_MMC1 write at address: 0x%04X", aAddress)
            break
        }
    }

    private func loadRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        if aValue & 0x80 == 0x80
        {
            self.shiftRegister = 0x10
            self.writeControl(value: self.control | 0x0C)
        }
        else
        {
            let complete: Bool = self.shiftRegister & 1 == 1
            self.shiftRegister >>= 1
            self.shiftRegister |= (aValue & 1) << 4
            if complete
            {
                self.writeRegister(address: aAddress, value: self.shiftRegister)
                self.shiftRegister = 0x10
            }
        }
    }

    private func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x8000 ... 0x9FFF:
            self.writeControl(value: aValue)
        case 0xA000 ... 0xBFFF:
            self.writeCHRBank0(value: aValue)
        case 0xC000 ... 0xDFFF:
            self.writeCHRBank1(value: aValue)
        case 0xE000 ... 0xFFFF:
            self.writePRGBank(value: aValue)
        default:
            break
        }
    }

    // Control (internal, $8000-$9FFF)
    private func writeControl(value aValue: UInt8)
    {
        self.control = aValue
        self.chrMode = (aValue >> 4) & 1
        self.prgMode = (aValue >> 2) & 3
        let mirror: UInt8 = aValue & 3
        switch mirror {
        case 0:
            self.mirroringMode = .single0
        case 1:
            self.mirroringMode = .single1
        case 2:
            self.mirroringMode = .vertical
        case 3:
            self.mirroringMode = .horizontal
        default: break
        }
        self.updateOffsets()
    }

    // CHR bank 0 (internal, $A000-$BFFF)
    private func writeCHRBank0(value aValue: UInt8)
    {
        self.chrBank0 = aValue
        self.updateOffsets()
    }

    // CHR bank 1 (internal, $C000-$DFFF)
    private func writeCHRBank1(value aValue: UInt8)
    {
        self.chrBank1 = aValue
        self.updateOffsets()
    }

    // PRG bank (internal, $E000-$FFFF)
    private func writePRGBank(value aValue: UInt8)
    {
        self.prgBank = aValue & 0x0F
        self.updateOffsets()
    }

    private func prgBankOffset(index aIndex: Int) -> Int
    {
        var index = aIndex
        if index >= 0x80
        {
            index -= 0x100
        }
        index %= self.prg.count / 0x4000
        var offset = index * 0x4000
        
        if offset < 0
        {
            offset += self.prg.count
        }
        
        return offset
    }

    private func chrBankOffset(index aIndex: Int) -> Int
    {
        var index = aIndex
        if index >= 0x80
        {
            index -= 0x100
        }
        
        index %= self.chr.count / 0x1000
        
        var offset = index * 0x1000
        if offset < 0
        {
            offset += self.chr.count
        }
        
        return offset
    }

    // PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
    //                    2: fix first bank at $8000 and switch 16 KB bank at $C000;
    //                    3: fix last bank at $C000 and switch 16 KB bank at $8000)
    // CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
    private func updateOffsets()
    {
        switch self.prgMode
        {
        case 0, 1:
            self.prgOffsets[0] = self.prgBankOffset(index: Int(self.prgBank & 0xFE))
            self.prgOffsets[1] = self.prgBankOffset(index: Int(self.prgBank | 0x01))
        case 2:
            self.prgOffsets[0] = 0
            self.prgOffsets[1] = self.prgBankOffset(index:Int(self.prgBank))
        case 3:
            self.prgOffsets[0] = self.prgBankOffset(index:Int(self.prgBank))
            self.prgOffsets[1] = self.prgBankOffset(index: -1)
        default: break
        }
        
        switch self.chrMode
        {
        case 0:
            self.chrOffsets[0] = self.chrBankOffset(index:Int(self.chrBank0 & 0xFE))
            self.chrOffsets[1] = self.chrBankOffset(index:Int(self.chrBank0 | 0x01))
        case 1:
            self.chrOffsets[0] = self.chrBankOffset(index:Int(self.chrBank0))
            self.chrOffsets[1] = self.chrBankOffset(index:Int(self.chrBank1))
        default: break
        }
    }
}
