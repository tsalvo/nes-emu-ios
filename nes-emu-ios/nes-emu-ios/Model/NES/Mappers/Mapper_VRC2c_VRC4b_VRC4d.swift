//
//  Mapper_VRC2c_VRC4b_VRC4d.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 8/15/21.
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

struct Mapper_VRC2c_VRC4b_VRC4d: MapperProtocol
{
    static private let scalerPreset: Int = 341
    
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = false
    
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    
    /// CHR bank offsets (in 1 KiB)
    private var chrBankOffsets: [Int] = [Int](repeating: 0, count: 8)
    
    private var chrBankLowHigh: [UInt8] = [UInt8](repeating: 0, count: 16)
    
    private var prgOffsets: [Int] = [Int](repeating: 0, count: 4)
    
    private var prgBank800XRegOffset: Int = 0
    
    private var sram: [UInt8] = [UInt8](repeating: 0, count: 8192)
    
    private var swapMode: Bool = false
    
    private var irqEnableAfterAcknowledgement: Bool = false
    
    private var irqEnable: Bool = false
    
    private var irqCycleMode: Bool = false
    
    /// IRQ Latch Reload Value
    private var irqLatch: UInt8 = 0
    
    private var irqCounter: UInt8 = 0
    
    private var irqScaler: Int = Mapper_VRC2c_VRC4b_VRC4d.scalerPreset
    
    private var irqLine: Bool = false
    
    private let prgBankMask: UInt8
    
    private let chrBankMask: UInt8
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        self.mirroringMode = aCartridge.header.mirroringMode
        
        for c in aCartridge.chrBlocks
        {
            self.chr.append(contentsOf: c)
        }
        
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }
        
        self.prgOffsets[2] = max(0, self.prg.count - 0x4000) // 16KB from end
        self.prgOffsets[3] = max(0, self.prg.count - 0x2000) // 8KB from end
        
        self.prgBankMask = self.prg.count > 256 * 1024 ? 0x1F : 0x0F
        self.chrBankMask = self.chr.count > 256 * 1024 ? 0x1F : self.chr.count > 128 * 1024 ? 0x0F : 0x07
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [], bools: [], uint8s: [], chr: self.chr)
        }
        set
        {
            self.chr = newValue.chr
        }
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x6000 ... 0x7FFF:
            return self.sram[Int(aAddress - 0x6000)]
        case 0x8000 ... 0xFFFF:
            let bank = (aAddress - 0x8000) / 0x2000
            let offset = aAddress % 0x2000
            return self.prg[self.prgOffsets[Int(bank)] + Int(offset)]
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d CPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        // account for VRC variants
        let adjustedAddress: UInt16
        
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            let A0 = ((aAddress >> 1) | (aAddress >> 3)) & 1
            let A1 = (aAddress | (aAddress >> 2)) & 1
            let translatedAddress = (aAddress & 0xFF00) | (A1 << 1) | A0
            adjustedAddress = translatedAddress & 0xF00F
        default: adjustedAddress = aAddress
        }
        
        switch adjustedAddress
        {
        case 0x6000 ... 0x7FFF:
            self.sram[Int(adjustedAddress - 0x6000)] = aValue
        case 0x8000 ... 0x8003:
            /*
             7  bit  0
             ---------
             ...P PPPP
                | ||||
                +-++++- Select 8 KiB PRG bank at $8000 or $C000 depending on Swap Mode
             */
            self.prgBank800XRegOffset = Int(aValue & self.prgBankMask) * 0x2000
            self.prgOffsets[self.swapMode ? 2 : 0] = self.prgBank800XRegOffset
        case 0x9000:
            /*
             7  bit  0
             ---------
             .... ..MM
                    ||
                    ++- Mirroring (0: vertical; 1: horizontal; 2: one-screen, lower bank; 3: one-screen, upper bank)
             */
            switch aValue & 0x03
            {
            case 0: self.mirroringMode = .vertical
            case 1: self.mirroringMode = .horizontal
            case 2: self.mirroringMode = .single0
            case 3: self.mirroringMode = .single1
            default: break
            }
        case 0x9002:
            /*
             7  bit  0
             ---------
             .... ..M.
                    |
                    +-- Swap Mode (used in VRC4 only)
             This register is VRC4 only.
             When 'M' is clear:
             the 8 KiB page at $8000 is controlled by the $800x register
             the 8 KiB page at $C000 is fixed to the second last 8 KiB in the ROM
             When 'M' is set:
             the 8 KiB page at $8000 is fixed to the second last 8 KiB in the ROM
             the 8 KiB page at $C000 is controlled by the $800x register
             */
            self.swapMode = (aValue >> 1) & 1 == 1
            
            self.prgOffsets[self.swapMode ? 0 : 2] = max(0, self.prg.count - 0x4000)
            self.prgOffsets[self.swapMode ? 2 : 0] = self.prgBank800XRegOffset

        case 0xA000 ... 0xA003:
            /*
             7  bit  0
             ---------
             ...P PPPP
                | ||||
                +-++++- Select 8 KiB PRG bank at $A000
             */
            self.prgOffsets[1] = Int(aValue & self.prgBankMask) * 0x2000
            
        case 0xB000:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[0] = low
            self.chrBankOffsets[0] = Int((self.chrBankLowHigh[1] & 0xF0) | low) * 0x0400
        case 0xB001:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[1] = hi
            self.chrBankOffsets[0] = Int(hi | self.chrBankLowHigh[0]) * 0x0400
            
        case 0xB002:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[2] = low
            self.chrBankOffsets[1] = Int((self.chrBankLowHigh[3] & 0xF0) | low) * 0x0400
        case 0xB003:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[3] = hi
            self.chrBankOffsets[1] = Int(hi | self.chrBankLowHigh[2]) * 0x0400
            
        case 0xC000:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[4] = low
            self.chrBankOffsets[2] = Int((self.chrBankLowHigh[5] & 0xF0) | low) * 0x0400
        case 0xC001:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[5] = hi
            self.chrBankOffsets[2] = Int(hi | self.chrBankLowHigh[4]) * 0x0400
            
        case 0xC002:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[6] = low
            self.chrBankOffsets[3] = Int((self.chrBankLowHigh[7] & 0xF0) | low) * 0x0400
        case 0xC003:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[7] = hi
            self.chrBankOffsets[3] = Int(hi | self.chrBankLowHigh[6]) * 0x0400
            
        case 0xD000:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[8] = low
            self.chrBankOffsets[4] = Int((self.chrBankLowHigh[9] & 0xF0) | low) * 0x0400
        case 0xD001:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[9] = hi
            self.chrBankOffsets[4] = Int(hi | self.chrBankLowHigh[8]) * 0x0400
            
        case 0xD002:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[10] = low
            self.chrBankOffsets[5] = Int((self.chrBankLowHigh[11] & 0xF0) | low) * 0x0400
        case 0xD003:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[11] = hi
            self.chrBankOffsets[5] = Int(hi | self.chrBankLowHigh[10]) * 0x0400
            
        case 0xE000:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[12] = low
            self.chrBankOffsets[6] = Int((self.chrBankLowHigh[13] & 0xF0) | low) * 0x0400
        case 0xE001:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[13] = hi
            self.chrBankOffsets[6] = Int(hi | self.chrBankLowHigh[12]) * 0x0400
            
        case 0xE002:
            let low: UInt8 = aValue & 0x0F
            self.chrBankLowHigh[14] = low
            self.chrBankOffsets[7] = Int((self.chrBankLowHigh[15] & 0xF0) | low) * 0x0400
        case 0xE003:
            let hi: UInt8 = ((aValue & 0x1F) << 4)
            self.chrBankLowHigh[15] = hi
            self.chrBankOffsets[7] = Int(hi | self.chrBankLowHigh[14]) * 0x0400
            
        case 0xF000:
            // $F000:  IRQ Latch, low 4 bits
            /*
             7  bit  0
             ---------
             .... LLLL
                  ||||
                  ++++- IRQ Latch (reload value)
             */
            self.irqLatch = (aValue & 0x0F) | (self.irqLatch & 0xF0)
        case 0xF001:
            // $F001:  IRQ Latch, high 4 bits
            /*
             7  bit  0
             ---------
             LLLL ....
             ||||
             ++++------ IRQ Latch (reload value)
             */
            self.irqLatch = ((aValue & 0x0F) << 4) | (self.irqLatch & 0x0F)
        case 0xF002:
            // $F002:  IRQ Control
            /*
             7  bit  0
             ---------
             .... .MEA
                   |||
                   ||+- IRQ Enable after acknowledgement (see IRQ Acknowledge)
                   |+-- IRQ Enable (1 = enabled)
                   +--- IRQ Mode (1 = cycle mode, 0 = scanline mode)
             */
            self.irqEnableAfterAcknowledgement = aValue & 1 == 1
            self.irqEnable = (aValue >> 1) & 1 == 1
            self.irqCycleMode = (aValue >> 2) & 1 == 1
            self.irqLine = false
            if self.irqEnable
            {
                self.irqCounter = self.irqLatch
                self.irqScaler = Mapper_VRC2c_VRC4b_VRC4d.scalerPreset
            }

        case 0xF003:
            // $F003:  IRQ Acknowledge
            self.irqLine = false
            self.irqEnable = self.irqEnableAfterAcknowledgement
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d CPU write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        switch aAddress {
        case 0x0000 ... 0x1FFF:
            let bankOffset: Int = self.chrBankOffsets[Int(aAddress / 0x0400)]
            let offset = Int(aAddress) % 0x0400
            return self.chr[bankOffset + offset]
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d PPU read at address: 0x%04X", aAddress)
            return 0
        }
        
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d PPU write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        guard self.irqEnable else { return MapperStepResults(requestedCPUInterrupt: nil) }
        
        if self.irqCycleMode
        {
            if self.irqCounter == 0xFF
            {
                self.irqCounter = self.irqLatch
                self.irqLine = true
            }
            else
            {
                self.irqCounter += 1
            }
        }
        else
        {
            self.irqScaler -= 3
            
            if self.irqScaler <= 0
            {
                self.irqScaler += Mapper_VRC2c_VRC4b_VRC4d.scalerPreset
                
                if self.irqCounter == 0xFF
                {
                    self.irqCounter = self.irqLatch
                    self.irqLine = true
                }
                else
                {
                    self.irqCounter += 1
                }
            }
        }
        
        return MapperStepResults(requestedCPUInterrupt: self.irqLine ? .irq : nil)
    }
}
