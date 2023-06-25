//
//  Mapper_TQROM.swift
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

struct Mapper_TQROM: MapperProtocol
{
    // MARK: - Constants
    static private let chrRamSize: Int = 8192
    
    // MARK: - Internal Variables
    let hasStep: Bool = true
    let hasExtendedNametableMapping: Bool = false
    private(set) var mirroringMode: MirroringMode
    
    // MARK: - Private Variables
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    /// 8KB of CHR RAM, selectable with bit 6 of
    private var chrRam: [UInt8] = [UInt8].init(repeating: 0, count: Mapper_TQROM.chrRamSize)
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    private let last8KBPrgOffset: Int
    private let last16KBPrgOffset: Int
    private var register: UInt8
    private var registers: [UInt8]
    private var prgMode: UInt8
    private var chrMode: UInt8
    private var prgOffsets: [Int]
    private var chrOffsets: [Int]
    private var reload: UInt8
    private var counter: UInt8
    private var irqEnable: Bool
    
    // MARK: - Life Cycle
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks.prefix(8) // max 8 PRG blocks (128KB)
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks.prefix(8) // max 8 CHR blocks (64KB)
        {
            c.append(contentsOf: cBlock)
        }
        
        let last8KBPrgOffset = max(p.count - 0x2000, 0)
        let last16KBPrgOffset = max(p.count - 0x4000, 0)
        
        self.last8KBPrgOffset = last8KBPrgOffset
        self.last16KBPrgOffset = last16KBPrgOffset
        
        self.chr = c
        self.prg = p
        
        if let safeState = aState,
           safeState.uint8s.count >= 13 + Mapper_TQROM.chrRamSize,
           safeState.bools.count >= 1,
           safeState.ints.count >= 12
        {
            self.mirroringMode = MirroringMode.init(rawValue: Int(safeState.mirroringMode)) ?? aCartridge.header.mirroringMode
            self.prgOffsets = [safeState.ints[0], safeState.ints[1], safeState.ints[2], safeState.ints[3]]
            self.chrOffsets = [safeState.ints[4], safeState.ints[5], safeState.ints[6], safeState.ints[7], safeState.ints[8], safeState.ints[9], safeState.ints[10], safeState.ints[11]]
            self.irqEnable = safeState.bools[0]
            self.register = safeState.uint8s[0]
            self.registers = [safeState.uint8s[1], safeState.uint8s[2], safeState.uint8s[3], safeState.uint8s[4], safeState.uint8s[5], safeState.uint8s[6], safeState.uint8s[7], safeState.uint8s[8]]
            self.prgMode = safeState.uint8s[9]
            self.chrMode = safeState.uint8s[10]
            self.reload = safeState.uint8s[11]
            self.counter = safeState.uint8s[12]
            self.chrRam = [UInt8](safeState.uint8s[13 ..< 13 + Mapper_TQROM.chrRamSize])
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
            self.prgOffsets[0] = 0
            self.prgOffsets[1] = p.count > 0x2000 ? 0x2000 : 0
            self.prgOffsets[2] = last16KBPrgOffset
            self.prgOffsets[3] = last8KBPrgOffset
        }
    }
    
    // MARK: - Save State
    var mapperState: MapperState
    {
        get
        {
            var u8: [UInt8] = [self.register, self.registers[0], self.registers[1], self.registers[2], self.registers[3], self.registers[4], self.registers[5], self.registers[6], self.registers[7], self.prgMode, self.chrMode, self.reload, self.counter]
            u8.append(contentsOf: self.chrRam)
            return MapperState(mirroringMode: UInt8(self.mirroringMode.rawValue), ints: [self.prgOffsets[0], self.prgOffsets[1], self.prgOffsets[2], self.prgOffsets[3], self.chrOffsets[0], self.chrOffsets[1], self.chrOffsets[2], self.chrOffsets[3], self.chrOffsets[4], self.chrOffsets[5], self.chrOffsets[6], self.chrOffsets[7]], bools: [self.irqEnable], uint8s: u8, chr: [])
        }
        set
        {
            guard newValue.uint8s.count >= 13 + Mapper_TQROM.chrRamSize,
                  newValue.bools.count >= 1,
                  newValue.ints.count >= 12
            else
            {
                return
            }
            
            self.mirroringMode = MirroringMode(rawValue: Int(newValue.mirroringMode)) ?? self.mirroringMode
            self.prgOffsets = [newValue.ints[0], newValue.ints[1], newValue.ints[2], newValue.ints[3]]
            self.chrOffsets = [newValue.ints[4], newValue.ints[5], newValue.ints[6], newValue.ints[7], newValue.ints[8], newValue.ints[9], newValue.ints[10], newValue.ints[11]]
            self.irqEnable = newValue.bools[0]
            self.register = newValue.uint8s[0]
            self.registers = [newValue.uint8s[1], newValue.uint8s[2], newValue.uint8s[3], newValue.uint8s[4], newValue.uint8s[5], newValue.uint8s[6], newValue.uint8s[7], newValue.uint8s[8]]
            self.prgMode = newValue.uint8s[9]
            self.chrMode = newValue.uint8s[10]
            self.reload = newValue.uint8s[11]
            self.counter = newValue.uint8s[12]
            self.chrRam = [UInt8](newValue.uint8s[13 ..< 13 + Mapper_TQROM.chrRamSize])
        }
    }
    
    // MARK: - CPU Access
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
        case 0x8000 ... 0x9FFF:
            if aAddress % 2 == 0
            {
                /* Bank Select
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
                self.prgMode = (aValue >> 6) & 1
                self.chrMode = (aValue >> 7) & 1
                self.register = aValue & 7
            }
            else
            {
                /* Bank Data (TQROM differs here from standard MMC3)
                 7  bit  0
                 ---- ----
                 xCDD DDDD
                  ||| ||||
                  |++-++++- New bank value, based on last value written to Bank select register
                  |         0: Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF);
                  |         1: Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF);
                  |         2: Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
                  |         3: Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
                  |         4: Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
                  |         5: Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
                  |         6, 7: As standard MMC3
                  +-------- Chip select (for CHR banks)
                            0: Select CHR ROM; 1: Select CHR RAM
                 */
                self.registers[Int(self.register)] = aValue & 0x7F // get low 7 bits only
            }
            
            // update offsets
            switch self.prgMode {
            case 0:
                self.prgOffsets[0] = Int(self.registers[6] & 0x3F) * 0x2000
                self.prgOffsets[1] = Int(self.registers[7] & 0x3F) * 0x2000
                self.prgOffsets[2] = self.last16KBPrgOffset
                self.prgOffsets[3] = self.last8KBPrgOffset
            case 1:
                self.prgOffsets[0] = self.last16KBPrgOffset
                self.prgOffsets[1] = Int(self.registers[7] & 0x3F) * 0x2000
                self.prgOffsets[2] = Int(self.registers[6] & 0x3F) * 0x2000
                self.prgOffsets[3] = self.last8KBPrgOffset
            default: break
            }
            
            switch self.chrMode {
            case 0:
                self.chrOffsets[0] = Int(self.registers[0] & 0xFE) * 0x0400
                self.chrOffsets[1] = Int(self.registers[0] | 0x01) * 0x0400
                self.chrOffsets[2] = Int(self.registers[1] & 0xFE) * 0x0400
                self.chrOffsets[3] = Int(self.registers[1] | 0x01) * 0x0400
                self.chrOffsets[4] = Int(self.registers[2]) * 0x0400
                self.chrOffsets[5] = Int(self.registers[3]) * 0x0400
                self.chrOffsets[6] = Int(self.registers[4]) * 0x0400
                self.chrOffsets[7] = Int(self.registers[5]) * 0x0400
            case 1:
                self.chrOffsets[0] = Int(self.registers[2]) * 0x0400
                self.chrOffsets[1] = Int(self.registers[3]) * 0x0400
                self.chrOffsets[2] = Int(self.registers[4]) * 0x0400
                self.chrOffsets[3] = Int(self.registers[5]) * 0x0400
                self.chrOffsets[4] = Int(self.registers[0] & 0xFE) * 0x0400
                self.chrOffsets[5] = Int(self.registers[0] | 0x01) * 0x0400
                self.chrOffsets[6] = Int(self.registers[1] & 0xFE) * 0x0400
                self.chrOffsets[7] = Int(self.registers[1] | 0x01) * 0x0400
            default: break
            }
        case 0xA000 ... 0xBFFF:
            if aAddress % 2 == 0
            {
                /* Mirroring
                 7  bit  0
                 ---- ----
                 xxxx xxxM
                         |
                         +- Nametable mirroring (0: vertical; 1: horizontal)
                 */
                /// This bit has no effect on cartridges with hardwired 4-screen VRAM. In the iNES and NES 2.0 formats, this can be identified through bit 3 of byte $06 of the header.
                if self.mirroringMode != .fourScreen {
                    self.mirroringMode = aValue & 1 == 0 ? .vertical : .horizontal // TODO: Check for hard-wired 4-screen VRAM
                }
            }
            else
            {
                /* PRG RAM protect
                 7  bit  0
                 ---- ----
                 RWXX xxxx
                 ||||
                 ||++------ Nothing on the MMC3, see MMC6
                 |+-------- Write protection (0: allow writes; 1: deny writes)
                 +--------- PRG RAM chip enable (0: disable; 1: enable)
                 */
                /// Disabling PRG RAM through bit 7 causes reads from the PRG RAM region to return open bus.
                /// Though these bits are functional on the MMC3, their main purpose is to write-protect save RAM during power-off. Many emulators choose not to implement them as part of iNES Mapper 4 to avoid an incompatibility with the MMC6.
                break
            }
        case 0xC000 ... 0xDFFF:
            if aAddress % 2 == 0
            {
                /* IRQ latch
                 7  bit  0
                 ---- ----
                 DDDD DDDD
                 |||| ||||
                 ++++-++++- IRQ latch value
                 */
                /// This register specifies the IRQ counter reload value. When the IRQ counter is zero (or a reload is requested through $C001), this value will be copied to the IRQ counter at the NEXT rising edge of the PPU address, presumably at PPU cycle 260 of the current scanline.
                /// The exact number of scanlines between IRQs is N+1, where N is the value written to $C000. 1 (Sharp MMC3B, MMC3C) or 2 (MMC3A, Non-Sharp MMC3B) to 256 scanlines are supported.
                self.reload = aValue // TODO: should this be (aValue + 1) ?
            }
            else
            {
                /* IRQ Reload
                 7  bit  0
                 ---- ----
                 xxxx xxxx
                 */
                /// Writing any value to this register reloads the MMC3 IRQ counter at the NEXT rising edge of the PPU address, presumably at PPU cycle 260 of the current scanline.
                self.counter = 0 // TODO: should we wait until the next cycle 260 to set counter to zero?
            }
        case 0xE000 ... 0xFFFF:
            // EVEN: Writing any value to this register will disable MMC3 interrupts AND acknowledge any pending interrupts.
            // ODD: Writing any value to this register will enable MMC3 interrupts.
            self.irqEnable = aAddress % 2 == 1
        case 0x6000 ... 0x7FFF:
            self.sram[Int(aAddress) - 0x6000] = aValue
        default:
            os_log("unhandled Mapper_TxSROM CPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    // MARK: - PPU Access
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x0400
            let bankOffset = self.chrOffsets[Int(bank)]
            let isChrRam = bankOffset >= self.chr.count
            let adjustedBankOffset = isChrRam ? bankOffset % Mapper_TQROM.chrRamSize : bankOffset
            let offset = aAddress % 0x0400
            let index: Int = adjustedBankOffset + Int(offset)
            return isChrRam ? self.chrRam[index] : self.chr[index]
        default:
            os_log("unhandled Mapper_TxSROM PPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bankOffset = self.chrOffsets[Int(aAddress / 0x0400)]
            guard bankOffset >= self.chr.count else {
                break
            }
            let adjustedBankOffset = bankOffset % Mapper_TQROM.chrRamSize
            let index: Int = adjustedBankOffset + Int(aAddress % 0x0400)
            self.chrRam[index] = aValue
        default:
            os_log("unhandled Mapper_TxSROM PPU write at address: 0x%04X", aAddress)
        }
    }
    
    // MARK: - Step
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        /// When using 8x8 sprites, if the BG uses $0000, and the sprites use $1000, the IRQ counter should decrement on PPU cycle 260, right after the visible part of the target scanline has ended.
        /// When using 8x8 sprites, if the BG uses $1000, and the sprites use $0000, the IRQ counter should decrement on PPU cycle 324 of the previous scanline (as in, right before the target scanline is about to be drawn). However, the 2C02's pre-render scanline will decrement the counter twice every other vertical redraw, so the IRQ will shake one scanline. This is visible in Wario's Woods.
        if aMapperStepInput.ppuCycle != 280 // TODO: this should be 260 or 324
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
        
        return MapperStepResults(requestedCPUInterrupt: shouldTriggerIRQ ? .irq : nil)
    }
}

