//
//  Mapper_TxSROM.swift
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
// https://archive.nes.science/nesdev-forums/f3/t11129.xhtml


struct Mapper_TxSROM: MapperProtocol
{
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = true
    
    let mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var register: UInt8
    private var registers: [UInt8]
    private var prgMode: UInt8
    private var chrMode: UInt8
    private var prgOffsets: [Int]
    private var chrOffsets: [Int]
    private var reload: UInt8
    private var counter: UInt8
    private var irqEnable: Bool
    
    /// nametables A and B combined
    private var nametable: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    private var nameTableA: Int = 0
    private var nameTableB: Int = 0
    private var nameTableC: Int = 0
    private var nameTableD: Int = 0
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }

        if let safeState = aState,
           safeState.uint8s.count >= 13 + 2048,
           safeState.bools.count >= 1,
           safeState.ints.count >= 16
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.prgOffsets = [safeState.ints[0], safeState.ints[1], safeState.ints[2], safeState.ints[3]]
            self.chrOffsets = [safeState.ints[4], safeState.ints[5], safeState.ints[6], safeState.ints[7], safeState.ints[8], safeState.ints[9], safeState.ints[10], safeState.ints[11]]
            self.nameTableA = safeState.ints[12]
            self.nameTableB = safeState.ints[13]
            self.nameTableC = safeState.ints[14]
            self.nameTableD = safeState.ints[15]
            self.irqEnable = safeState.bools[0]
            self.register = safeState.uint8s[0]
            self.registers = [safeState.uint8s[1], safeState.uint8s[2], safeState.uint8s[3], safeState.uint8s[4], safeState.uint8s[5], safeState.uint8s[6], safeState.uint8s[7], safeState.uint8s[8]]
            self.prgMode = safeState.uint8s[9]
            self.chrMode = safeState.uint8s[10]
            self.reload = safeState.uint8s[11]
            self.counter = safeState.uint8s[12]
            self.nametable = [UInt8](safeState.uint8s[13 ..< 13 + 2048])
            self.chr = safeState.chr
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.prgOffsets = [Int].init(repeating: 0, count: 4)
            self.chrOffsets = [Int].init(repeating: 0, count: 8)
            self.irqEnable = false
            self.register = 0
            self.registers = [UInt8].init(repeating: 0, count: 8)
            self.prgMode = 0
            self.chrMode = 0
            self.reload = 0
            self.counter = 0
            
            self.prgOffsets[0] = self.prgBankOffset(index: 0)
            self.prgOffsets[1] = self.prgBankOffset(index: 1)
            self.prgOffsets[2] = self.prgBankOffset(index: -2)
            self.prgOffsets[3] = self.prgBankOffset(index: -1)
            
            if let safeState = aState
            {
                self.chr = safeState.chr
            }
            else
            {
                for c in aCartridge.chrBlocks
                {
                    self.chr.append(contentsOf: c)
                }
            }

            if self.chr.count == 0
            {
                // use a block for CHR RAM if no block exists
                self.chr.append(contentsOf: [UInt8].init(repeating: 0, count: 8192))
            }
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            var uint8s = [self.register, self.registers[0], self.registers[1], self.registers[2], self.registers[3], self.registers[4], self.registers[5], self.registers[6], self.registers[7], self.prgMode, self.chrMode, self.reload, self.counter]
            uint8s.append(contentsOf: self.nametable)
            return MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prgOffsets[0], self.prgOffsets[1], self.prgOffsets[2], self.prgOffsets[3], self.chrOffsets[0], self.chrOffsets[1], self.chrOffsets[2], self.chrOffsets[3], self.chrOffsets[4], self.chrOffsets[5], self.chrOffsets[6], self.chrOffsets[7], self.nameTableA, self.nameTableB, self.nameTableC, self.nameTableD], bools: [self.irqEnable], uint8s: uint8s, chr: self.chr)
        }
        set
        {
            guard newValue.uint8s.count >= 13 + 2048,
                  newValue.bools.count >= 1,
                  newValue.ints.count >= 16
            else
            {
                return
            }
            
            self.prgOffsets = [newValue.ints[0], newValue.ints[1], newValue.ints[2], newValue.ints[3]]
            self.chrOffsets = [newValue.ints[4], newValue.ints[5], newValue.ints[6], newValue.ints[7], newValue.ints[8], newValue.ints[9], newValue.ints[10], newValue.ints[11]]
            
            self.nameTableA = newValue.ints[12]
            self.nameTableB = newValue.ints[13]
            self.nameTableC = newValue.ints[14]
            self.nameTableD = newValue.ints[15]
            self.irqEnable = newValue.bools[0]
            self.register = newValue.uint8s[0]
            self.registers = [newValue.uint8s[1], newValue.uint8s[2], newValue.uint8s[3], newValue.uint8s[4], newValue.uint8s[5], newValue.uint8s[6], newValue.uint8s[7], newValue.uint8s[8]]
            self.prgMode = newValue.uint8s[9]
            self.chrMode = newValue.uint8s[10]
            self.reload = newValue.uint8s[11]
            self.counter = newValue.uint8s[12]
            self.nametable = [UInt8](newValue.uint8s[13 ..< 13 + 2048])
            self.chr = newValue.chr
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            let address = aAddress - 0x8000
            let bank = address / 0x2000
            let offset = address % 0x2000
            return self.prg[self.prgOffsets[Int(bank)] + Int(offset)]
        case 0x6000 ... 0x7FFF:
            return self.sram[Int(aAddress) - 0x6000]
        default:
            os_log("unhandled Mapper_TxSROM CPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            self.writeRegister(address: aAddress, value: aValue)
        case 0x6000 ... 0x7FFF:
            self.sram[Int(aAddress) - 0x6000] = aValue
        default:
            os_log("unhandled Mapper_TxSROM CPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x2FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            return self.chr[self.chrOffsets[Int(bank)] + Int(offset)]
        case 0x2000 ... 0x23FF:
            return self.nametable[self.nameTableA * 0x400 + Int(aAddress % 0x400)]
        case 0x2400 ... 0x27FF:
            return self.nametable[self.nameTableB * 0x400 + Int(aAddress % 0x400)]
        case 0x2800 ... 0x2BFF:
            return self.nametable[self.nameTableC * 0x400 + Int(aAddress % 0x400)]
        case 0x2C00 ... 0x2FFF:
            return self.nametable[self.nameTableD * 0x400 + Int(aAddress % 0x400)]
        default:
            os_log("unhandled Mapper_TxSROM PPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x2FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
        case 0x2000 ... 0x23FF:
            self.nametable[self.nameTableA * 0x400 + Int(aAddress % 0x400)] = aValue
        case 0x2400 ... 0x27FF:
            self.nametable[self.nameTableB * 0x400 + Int(aAddress % 0x400)] = aValue
        case 0x2800 ... 0x2BFF:
            self.nametable[self.nameTableC * 0x400 + Int(aAddress % 0x400)] = aValue
        case 0x2C00 ... 0x2FFF:
            self.nametable[self.nameTableD * 0x400 + Int(aAddress % 0x400)] = aValue
        default:
            os_log("unhandled Mapper_TxSROM PPU write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        if aMapperStepInput.ppuCycle != 280 // TODO: this should be 260
        {
            return MapperStepResults(requestedCPUInterrupt: nil)
        }
        
        if aMapperStepInput.ppuScanline > 239 && aMapperStepInput.ppuScanline < 261
        {
            return MapperStepResults(requestedCPUInterrupt: nil)
        }
        
        if !aMapperStepInput.ppuShowBackground && !aMapperStepInput.ppuShowSprites
        {
            return MapperStepResults(requestedCPUInterrupt: nil)
        }
        
        let shouldTriggerIRQ = self.handleScanline()
        
        return MapperStepResults(requestedCPUInterrupt: shouldTriggerIRQ ? .irq : nil)
    }

    private mutating func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x8000 ... 0x9FFF:
            if aAddress % 2 == 0
            {
                self.writeBankSelect(value: aValue)
            }
            else
            {
                self.writeBankData(value: aValue)
            }
        case 0xA000 ... 0xBFFF:
            if aAddress % 2 == 0
            {
                self.writeMirror(value: aValue)
            }
            else
            {
                self.writeProtect()
            }
        case 0xC000 ... 0xDFFF:
            if aAddress % 2 == 0
            {
                self.writeIRQLatch(value: aValue)
            }
            else
            {
                self.writeIRQReload()
            }
        case 0xE000 ... 0xFFFF:
            self.irqEnable = aAddress % 2 == 1
        default: break
        }
    }

    private mutating func writeBankSelect(value aValue: UInt8)
    {
        self.prgMode = (aValue >> 6) & 1
        self.chrMode = (aValue >> 7) & 1
        self.register = aValue & 7
        self.updateOffsets()
    }

    private mutating func writeBankData(value aValue: UInt8)
    {
        /* MMC3
        7  bit  0
        ---- ----
        DDDD DDDD
        |||| ||||
        ++++-++++- New bank value, based on last value written to Bank select register (mentioned above)
         
         TxSROM
        7  bit  0
        ---- ----
        MDDD DDDD
        |||| ||||
        |+++-++++- New bank value, based on last value written to Bank select register
        |          0: Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF)
        |          1: Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF)
        |          2: Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF)
        |          3: Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF)
        |          4: Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF)
        |          5: Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF)
        |          6, 7: as standard MMC3
        |
        +--------- Mirroring configuration, based on the last value
                   written to Bank select register
                   0: Select Nametable at PPU $2000-$27FF
                   1: Select Nametable at PPU $2800-$2FFF
                   Note : Those bits are ignored if corresponding CHR banks
                   are mapped at $1000-$1FFF via $8000.
                   
                   2 : Select Nametable at PPU $2000-$23FF
                   3 : Select Nametable at PPU $2400-$27FF
                   4 : Select Nametable at PPU $2800-$2BFF
                   5 : Select Nametable at PPU $2C00-$2FFF
                   Note : Those bits are ignored if corresponding CHR banks
                   are mapped at $1000-$1FFF via $8000.
         */
        
        let nt: Int = Int(aValue >> 7)
        
        switch self.chrMode
        {
        case 0:
            switch self.register
            {
            case 0:
                self.nameTableA = nt
                self.nameTableB = nt
            case 1:
                self.nameTableC = nt
                self.nameTableD = nt
            default: break
            }
        default:
            switch self.register
            {
            case 2:
                self.nameTableA = nt
            case 3:
                self.nameTableB = nt
            case 4:
                self.nameTableC = nt
            case 5:
                self.nameTableD = nt
            default: break
            }
        }
        self.registers[Int(self.register)] = aValue
        self.updateOffsets()
    }

    private mutating func writeMirror(value aValue: UInt8)
    {
        // This does nothing in this mapper, as opposed to regular MMC3 where this would select the mirroring mode
    }

    private func writeProtect()
    {
        
    }
    
    private mutating func writeIRQLatch(value aValue: UInt8)
    {
        self.reload = aValue
    }

    private mutating func writeIRQReload()
    {
        self.counter = 0
    }

    private mutating func writeIRQDisable()
    {
        self.irqEnable = false
    }

    private mutating func writeIRQEnable()
    {
        self.irqEnable = true
    }

    private func prgBankOffset(index aIndex: Int) -> Int
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

    private func chrBankOffset(index aIndex: Int) -> Int
    {
        var index = aIndex
        if index >= 0x80
        {
            index -= 0x100
        }
        index %= (self.chr.count / 0x0400)
        var offset = index * 0x0400
        if offset < 0
        {
            offset += self.chr.count
        }
        return offset
    }

    private mutating func updateOffsets()
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
    
    private mutating func handleScanline() -> Bool
    {
        let shouldTriggerIRQ: Bool
        
        if self.counter == 0
        {
            self.counter = self.reload
            shouldTriggerIRQ = false
        }
        else
        {
            self.counter -= 1
            shouldTriggerIRQ = self.counter == 0 && self.irqEnable
        }
        
        return shouldTriggerIRQ
    }
}

