//
//  Mapper_MMC3.swift
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

struct Mapper_MMC3: MapperProtocol
{
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = false
    
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    
    /// 8KB of CHR RAM used if there is no CHR ROM onboard (used only on TNROM variant boards - Famicom only)
    private var chrRam: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
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
    private let isChrRamEnabled: Bool
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var prgRom: [UInt8] = []
        for p in aCartridge.prgBlocks
        {
            prgRom.append(contentsOf: p)
        }
        
        self.prg = prgRom
        
        var chrRom: [UInt8] = []
        for c in aCartridge.chrBlocks
        {
            chrRom.append(contentsOf: c)
        }
        
        self.chr = chrRom
        self.isChrRamEnabled = chrRom.isEmpty
        
        if let safeState = aState,
           safeState.uint8s.count >= 8205,
           safeState.bools.count >= 1,
           safeState.ints.count >= 12
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.prgOffsets = [safeState.ints[0], safeState.ints[1], safeState.ints[2], safeState.ints[3]]
            self.chrOffsets = [safeState.ints[4], safeState.ints[5], safeState.ints[6], safeState.ints[7], safeState.ints[8], safeState.ints[9], safeState.ints[10], safeState.ints[11]]
            self.irqEnable = safeState.bools[0]
            self.register = safeState.uint8s[0]
            self.registers = [safeState.uint8s[1], safeState.uint8s[2], safeState.uint8s[3], safeState.uint8s[4], safeState.uint8s[5], safeState.uint8s[6], safeState.uint8s[7], safeState.uint8s[8]]
            self.prgMode = safeState.uint8s[9]
            self.chrMode = safeState.uint8s[10]
            self.reload = safeState.uint8s[11]
            self.counter = safeState.uint8s[12]
            self.sram = [UInt8](safeState.uint8s[13 ..< 8205])
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
            self.sram = [UInt8].init(repeating: 0, count: 8192)
            
            self.prgOffsets[0] = self.prgBankOffset(index: 0)
            self.prgOffsets[1] = self.prgBankOffset(index: 1)
            self.prgOffsets[2] = self.prgBankOffset(index: -2)
            self.prgOffsets[3] = self.prgBankOffset(index: -1)
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            var u8s: [UInt8] = [self.register, self.registers[0], self.registers[1], self.registers[2], self.registers[3], self.registers[4], self.registers[5], self.registers[6], self.registers[7], self.prgMode, self.chrMode, self.reload, self.counter]
            u8s.append(contentsOf: self.sram)
            return MapperState(
                mirroringMode: self.mirroringMode.rawValue,
                ints: [self.prgOffsets[0], self.prgOffsets[1], self.prgOffsets[2], self.prgOffsets[3], self.chrOffsets[0], self.chrOffsets[1], self.chrOffsets[2], self.chrOffsets[3], self.chrOffsets[4], self.chrOffsets[5], self.chrOffsets[6], self.chrOffsets[7]],
                bools: [self.irqEnable],
                uint8s: u8s,
                chr: []
            )
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            
            guard newValue.uint8s.count >= 8205,
                  newValue.bools.count >= 1,
                  newValue.ints.count >= 12
            else
            {
                return
            }
            
            self.prgOffsets = [newValue.ints[0], newValue.ints[1], newValue.ints[2], newValue.ints[3]]
            self.chrOffsets = [newValue.ints[4], newValue.ints[5], newValue.ints[6], newValue.ints[7], newValue.ints[8], newValue.ints[9], newValue.ints[10], newValue.ints[11]]
            self.irqEnable = newValue.bools[0]
            self.register = newValue.uint8s[0]
            self.registers = [newValue.uint8s[1], newValue.uint8s[2], newValue.uint8s[3], newValue.uint8s[4], newValue.uint8s[5], newValue.uint8s[6], newValue.uint8s[7], newValue.uint8s[8]]
            self.prgMode = newValue.uint8s[9]
            self.chrMode = newValue.uint8s[10]
            self.reload = newValue.uint8s[11]
            self.counter = newValue.uint8s[12]
            self.sram = [UInt8](newValue.uint8s[13 ..< 8205])
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
            os_log("unhandled Mapper_MMC3 read at address: 0x%04X", aAddress)
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
            os_log("unhandled Mapper_MMC3 write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        if self.isChrRamEnabled
        {
            return self.chrRam[Int(aAddress)]
        }
        else
        {
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            return self.chr[self.chrOffsets[Int(bank)] + Int(offset)]
        }
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        if self.isChrRamEnabled
        {
            self.chrRam[Int(aAddress)] = aValue
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
        let isEven: Bool = aAddress & 0x0001 == 0
        switch aAddress
        {
        case 0x8000 ... 0x9FFF:
            switch isEven
            {
            case true:
                /*
                 Bank select ($8000-$9FFE, even)
                 7  bit  0
                 ---- ----
                 CPMx xRRR
                 |||   |||
                 |||   +++- Specify which bank register to update on next write to Bank Data register
                 |||          000: R0: Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF)
                 |||          001: R1: Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF)
                 |||          010: R2: Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF)
                 |||          011: R3: Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF)
                 |||          100: R4: Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF)
                 |||          101: R5: Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF)
                 |||          110: R6: Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF)
                 |||          111: R7: Select 8 KB PRG ROM bank at $A000-$BFFF
                 ||+------- Nothing on the MMC3, see MMC6
                 |+-------- PRG ROM bank mode (0: $8000-$9FFF swappable,
                 |                                $C000-$DFFF fixed to second-last bank;
                 |                             1: $C000-$DFFF swappable,
                 |                                $8000-$9FFF fixed to second-last bank)
                 +--------- CHR A12 inversion (0: two 2 KB banks at $0000-$0FFF,
                                                  four 1 KB banks at $1000-$1FFF;
                                               1: two 2 KB banks at $1000-$1FFF,
                                                  four 1 KB banks at $0000-$0FFF)
                 */
                self.prgMode = (aValue >> 6) & 0x01
                self.chrMode = (aValue >> 7) & 0x01
                self.register = aValue & 0x07
                self.updateOffsets()
            case false:
                /*
                 Bank data ($8001-$9FFF, odd)
                 7  bit  0
                 ---- ----
                 DDDD DDDD
                 |||| ||||
                 ++++-++++- New bank value, based on last value written to Bank select register (mentioned above)
                 */
                self.registers[Int(self.register)] = aValue
                self.updateOffsets()
            }
        case 0xA000 ... 0xBFFF:
            switch isEven
            {
            case true:
                /*
                 Mirroring ($A000-$BFFE, even)
                 7  bit  0
                 ---- ----
                 xxxx xxxM
                         |
                         +- Nametable mirroring (0: vertical; 1: horizontal)
                 */
                self.mirroringMode = aValue & 0x01 == 0 ? .vertical : .horizontal
            case false:
                /*
                 PRG RAM protect ($A001-$BFFF, odd)
                 7  bit  0
                 ---- ----
                 RWXX xxxx
                 ||||
                 ||++------ Nothing on the MMC3, see MMC6
                 |+-------- Write protection (0: allow writes; 1: deny writes)
                 +--------- PRG RAM chip enable (0: disable; 1: enable)
                 */
                break
            }
        case 0xC000 ... 0xDFFF:
            switch isEven
            {
            case true:
                /*
                 IRQ latch ($C000-$DFFE, even)
                 7  bit  0
                 ---- ----
                 DDDD DDDD
                 |||| ||||
                 ++++-++++- IRQ latch value
                 */
                self.reload = aValue
            case false:
                /*
                 IRQ reload ($C001-$DFFF, odd)
                 7  bit  0
                 ---- ----
                 xxxx xxxx
                 */
                self.counter = 0
            }
        case 0xE000 ... 0xFFFF:
            /*
             IRQ disable ($E000-$FFFE, even)
             IRQ enable ($E001-$FFFF, odd)
             */
            self.irqEnable = !isEven
        default: break
        }
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
        
        guard !self.isChrRamEnabled else { return } // prevent calling chrBankOffset with empty CHR ROM

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

