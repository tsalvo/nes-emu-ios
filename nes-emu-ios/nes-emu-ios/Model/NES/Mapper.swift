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
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?)
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
    
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?) { }
}

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
    
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?)
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
    
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?)
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

class Mapper_CNROM: MapperProtocol
{
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var chrBank: Int = 0
    
    private var prgBank1: Int = 0
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
        
        self.prgBank2 = aCartridge.prgBlocks.count - 1
    }
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000: // CHR Block
            return self.chr[(self.chrBank * 0x2000) + Int(aAddress)]
        case 0x8000 ..< 0xC000: // PRG Block 0
            return self.prg[self.prgBank1 * 0x4000 + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // PRG Block 1 (or mirror of PRG block 0 if only one PRG exists)
            return self.prg[self.prgBank2 * 0x4000 + Int(aAddress - 0xC000)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress - 0x6000)]
        default:
            os_log("unhandled Mapper_CNROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress {
        case 0x0000 ..< 0x2000: // CHR RAM?
            self.chr[(self.chrBank * 0x2000) + Int(aAddress)] = aValue
        case 0x8000 ... 0xFFFF:
            self.chrBank = Int(aValue & 3)
        case 0x6000 ..< 0x8000: // write to SRAM save
            self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_CNROM write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?)
    {
        
    }
}

class Mapper_MMC3: MapperProtocol
{
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    var register: UInt8 = 0
    var registers: [UInt8] = [UInt8].init(repeating: 0, count: 8)
    var prgMode: UInt8 = 0
    var chrMode: UInt8 = 0
    var prgOffsets: [Int] = [Int].init(repeating: 0, count: 4)
    var chrOffsets: [Int] = [Int].init(repeating: 0, count: 8)
    var reload: UInt8 = 0
    var counter: UInt8 = 0
    var irqEnable: Bool = false
    
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

        self.prgOffsets[0] = self.prgBankOffset(index: 0)
        self.prgOffsets[1] = self.prgBankOffset(index: 1)
        self.prgOffsets[2] = self.prgBankOffset(index: -2)
        self.prgOffsets[3] = self.prgBankOffset(index: -1)
    }
    
    func step(ppu aPPU: PPU?, cpu aCPU: CPU?)
    {
        guard let ppu = aPPU,
            let cpu = aCPU
        else
        {
            return
        }
        
        if ppu.cycle != 280 // TODO: this *should* be 260
        {
            return
        }
        
        if ppu.scanline > 239 && ppu.scanline < 261
        {
            return
        }
        
        if ppu.flagShowBackground == 0 && ppu.flagShowSprites == 0
        {
            return
        }
        
        self.handleScanline(cpu: cpu)
    }
    
    private func handleScanline(cpu aCPU: CPU)
    {
        if self.counter == 0
        {
            self.counter = self.reload
        }
        else
        {
            self.counter -= 1
            
            if self.counter == 0 && self.irqEnable
            {
                aCPU.triggerIRQ()
            }
        }
    }
    
    func read(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            return self.chr[self.chrOffsets[Int(bank)] + Int(offset)]
        case 0x8000 ... 0xFFFF:
            var address = aAddress
            address = address - 0x8000
            let bank = address / 0x2000
            let offset = address % 0x2000
            return self.prg[self.prgOffsets[Int(bank)] + Int(offset)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress) - 0x6000]
        default:
            os_log("unhandled Mapper_MMC3 read at address: 0x%04X", aAddress)
            return 0
        }
        
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x0000 ..< 0x2000:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
        case 0x8000 ... 0xFFFF:
            self.writeRegister(address: aAddress, value: aValue)
        case 0x6000 ..< 0x8000:
            self.sram[Int(aAddress) - 0x6000] = aValue
        default:
            os_log("unhandled Mapper_MMC3 write at address: 0x%04X", aAddress)
            break
        }
    }

    func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x8000 ..< 0xA000:
            if aAddress % 2 == 0
            {
                self.writeBankSelect(value: aValue)
            }
            else
            {
                self.writeBankData(value: aValue)
            }
        case 0xA000 ..< 0xC000:
            if aAddress % 2 == 0
            {
                self.writeMirror(value: aValue)
            }
            else
            {
                self.writeProtect(value: aValue)
            }
        case 0xC000 ..< 0xE000:
            if aAddress % 2 == 0
            {
                self.writeIRQLatch(value: aValue)
            }
            else
            {
                self.writeIRQReload(value: aValue)
            }
        case 0xE000 ... 0xFFFF:
            if aAddress % 2 == 0
            {
                self.writeIRQDisable(value: aValue)
            }
            else
            {
                self.writeIRQEnable(value: aValue)
            }
        default: break
        }
    }

    func writeBankSelect(value aValue: UInt8)
    {
        self.prgMode = (aValue >> 6) & 1
        self.chrMode = (aValue >> 7) & 1
        self.register = aValue & 7
        self.updateOffsets()
    }

    func writeBankData(value aValue: UInt8)
    {
        self.registers[Int(self.register)] = aValue
        self.updateOffsets()
    }

    func writeMirror(value aValue: UInt8)
    {
        switch aValue & 1
        {
        case 0:
            self.mirroringMode = .vertical
        case 1:
            self.mirroringMode = .horizontal
        default: break
        }
    }

    func writeProtect(value aValue: UInt8)
    {
        
    }
    
    func writeIRQLatch(value aValue: UInt8)
    {
        self.reload = aValue
    }

    func writeIRQReload(value aValue: UInt8)
    {
        self.counter = 0
    }

    func writeIRQDisable(value aValue: UInt8)
    {
        self.irqEnable = false
    }

    func writeIRQEnable(value aValue: UInt8)
    {
        self.irqEnable = true
    }

    func prgBankOffset(index aIndex: Int) -> Int
    {
        guard self.prg.count >= 0x2000 else { return 0 }
        
        var i = aIndex
        if i >= 0x80
        {
            i -= 0x100
        }
        
        i %= (self.prg.count / 0x2000)
        var offset = i * 0x2000
        if offset < 0
        {
            offset += self.prg.count
        }
        
        return offset
    }

    func chrBankOffset(index aIndex: Int) -> Int
    {
        var index = aIndex
        if index >= 0x80
        {
            index -= 0x100
        }
        index %= self.chr.count / 0x0400
        var offset = index * 0x0400
        if offset < 0
        {
            offset += self.chr.count
        }
        return offset
    }

    func updateOffsets()
    {
        switch self.prgMode {
        case 0:
            self.prgOffsets[0] = self.prgBankOffset(index: Int(self.registers[6]))
            self.prgOffsets[1] = self.prgBankOffset(index: Int(self.registers[7]))
            self.prgOffsets[2] = self.prgBankOffset(index: -2)
            self.prgOffsets[3] = self.prgBankOffset(index: -1)
        case 1:
            self.prgOffsets[0] = self.prgBankOffset(index: -2)
            self.prgOffsets[1] = self.prgBankOffset(index: Int(self.registers[7]))
            self.prgOffsets[2] = self.prgBankOffset(index: Int(self.registers[6]))
            self.prgOffsets[3] = self.prgBankOffset(index: -1)
        default: break
        }
        switch self.chrMode {
        case 0:
            self.chrOffsets[0] = self.chrBankOffset(index: Int(self.registers[0] & 0xFE))
            self.chrOffsets[1] = self.chrBankOffset(index: Int(self.registers[0] | 0x01))
            self.chrOffsets[2] = self.chrBankOffset(index: Int(self.registers[1] & 0xFE))
            self.chrOffsets[3] = self.chrBankOffset(index: Int(self.registers[1] | 0x01))
            self.chrOffsets[4] = self.chrBankOffset(index: Int(self.registers[2]))
            self.chrOffsets[5] = self.chrBankOffset(index: Int(self.registers[3]))
            self.chrOffsets[6] = self.chrBankOffset(index: Int(self.registers[4]))
            self.chrOffsets[7] = self.chrBankOffset(index: Int(self.registers[5]))
        case 1:
            self.chrOffsets[0] = self.chrBankOffset(index: Int(self.registers[2]))
            self.chrOffsets[1] = self.chrBankOffset(index: Int(self.registers[3]))
            self.chrOffsets[2] = self.chrBankOffset(index: Int(self.registers[4]))
            self.chrOffsets[3] = self.chrBankOffset(index: Int(self.registers[5]))
            self.chrOffsets[4] = self.chrBankOffset(index: Int(self.registers[0] & 0xFE))
            self.chrOffsets[5] = self.chrBankOffset(index: Int(self.registers[0] | 0x01))
            self.chrOffsets[6] = self.chrBankOffset(index: Int(self.registers[1] & 0xFE))
            self.chrOffsets[7] = self.chrBankOffset(index: Int(self.registers[1] | 0x01))
        default: break
        }
    }
}
