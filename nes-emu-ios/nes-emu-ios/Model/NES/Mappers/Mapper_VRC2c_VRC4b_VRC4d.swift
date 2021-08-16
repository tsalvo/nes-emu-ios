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
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = false
    
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// low 4 bytes and high 5 bytes for each of the 8 banks
    private var chrBanks: [UInt8] = [UInt8](repeating: 0, count: 16)
    
    /// CHR array index offsets for each of the 8x 1KB banks
    private var chrOffsets: [Int] = [Int](repeating: 0, count: 8)
    
    private var prgOffsets: [Int] = [Int](repeating: 0, count: 4)
    
    private var sram: [UInt8] = [UInt8](repeating: 0, count: 8192)
    
    private var swapMode: Bool = false
    
    private var irqEnableAfterAcknowledgement: Bool = false
    
    private var irqEnable: Bool = false
    
    private var irqCycleMode: Bool = false
    
    private var irqLatchReloadValue: UInt8 = 0
    
    private var irqCounter: UInt8 = 0
    
    private var prescaler: Int = 341
    
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
        switch aAddress
        {
        case 0x6000 ... 0x7FFF:
            self.sram[Int(aAddress - 0x6000)] = aValue
        case 0x8000 ... 0x8003:
            /*
            7  bit  0
            ---------
            ...P PPPP
               | ||||
               +-++++- Select 8 KiB PRG bank at $8000 or $C000 depending on Swap Mode
            */
            let prgBankIndex = self.swapMode ? 2 : 0
            self.prgOffsets[prgBankIndex] = Int(aValue & 0x0F) * 0x2000 // TODO: 0x1F for larger PRG ROMs?
        case 0x9000 ... 0x9001, 0x9003:
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
        case 0xA000 ... 0xA003:
            /*
            7  bit  0
            ---------
            ...P PPPP
               | ||||
               +-++++- Select 8 KiB PRG bank at $A000
            */
            self.prgOffsets[1] = Int(aValue & 0x0F) * 0x2000 // TODO: 0x1F for larger PRG ROMs?
        case 0xB000:
            /*
              $B000
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $0000
            */
            self.chrBanks[0] = aValue & 0x0F
            self.chrOffsets[0] = Int(UInt16(self.chrBanks[0]) | (UInt16(self.chrBanks[1]) << 4)) * 0x0400
        case 0xB001:
            /*
              $B001
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $0000
            */
            self.chrBanks[1] = aValue & 0x1F
            self.chrOffsets[0] = Int(UInt16(self.chrBanks[0]) | (UInt16(self.chrBanks[1]) << 4)) * 0x0400
        case 0xB002:
            /*
              $B002
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $0400
            */
            self.chrBanks[2] = aValue & 0x0F
            self.chrOffsets[1] = Int(UInt16(self.chrBanks[2]) | (UInt16(self.chrBanks[3]) << 4)) * 0x0400
        case 0xB003:
            /*
              $B003
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $0400
            */
            self.chrBanks[3] = aValue & 0x1F
            self.chrOffsets[1] = Int(UInt16(self.chrBanks[2]) | (UInt16(self.chrBanks[3]) << 4)) * 0x0400
        case 0xC000:
            /*
              $C000
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $0800
            */
            self.chrBanks[4] = aValue & 0x0F
            self.chrOffsets[2] = Int(UInt16(self.chrBanks[4]) | (UInt16(self.chrBanks[5]) << 4)) * 0x0400
        case 0xC001:
            /*
              $C001
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $0800
            */
            self.chrBanks[5] = aValue & 0x1F
            self.chrOffsets[2] = Int(UInt16(self.chrBanks[4]) | (UInt16(self.chrBanks[5]) << 4)) * 0x0400
        case 0xC002:
            /*
              $C002
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $0C00
            */
            self.chrBanks[6] = aValue & 0x0F
            self.chrOffsets[3] = Int(UInt16(self.chrBanks[6]) | (UInt16(self.chrBanks[7]) << 4)) * 0x0400
        case 0xC003:
            /*
              $C003
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $0C00
            */
            self.chrBanks[7] = aValue & 0x1F
            self.chrOffsets[3] = Int(UInt16(self.chrBanks[6]) | (UInt16(self.chrBanks[7]) << 4)) * 0x0400
        case 0xD000:
            /*
              $D000
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $1000
            */
            self.chrBanks[8] = aValue & 0x0F
            self.chrOffsets[4] = Int(UInt16(self.chrBanks[8]) | (UInt16(self.chrBanks[9]) << 4)) * 0x0400
        case 0xD001:
            /*
              $D001
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $1000
            */
            self.chrBanks[9] = aValue & 0x1F
            self.chrOffsets[4] = Int(UInt16(self.chrBanks[8]) | (UInt16(self.chrBanks[9]) << 4)) * 0x0400
        case 0xD002:
            /*
              $D002
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $1400
            */
            self.chrBanks[10] = aValue & 0x0F
            self.chrOffsets[5] = Int(UInt16(self.chrBanks[10]) | (UInt16(self.chrBanks[11]) << 4)) * 0x0400
        case 0xD003:
            /*
              $D003
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $1400
            */
            self.chrBanks[11] = aValue & 0x1F
            self.chrOffsets[5] = Int(UInt16(self.chrBanks[10]) | (UInt16(self.chrBanks[11]) << 4)) * 0x0400
        case 0xE000:
            /*
              $E000
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $1800
            */
            self.chrBanks[12] = aValue & 0x0F
            self.chrOffsets[6] = Int(UInt16(self.chrBanks[12]) | (UInt16(self.chrBanks[13]) << 4)) * 0x0400
        case 0xE001:
            /*
              $E001
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $1800
            */
            self.chrBanks[13] = aValue & 0x1F
            self.chrOffsets[6] = Int(UInt16(self.chrBanks[12]) | (UInt16(self.chrBanks[13]) << 4)) * 0x0400
        case 0xE002:
            /*
              $E002
              7  bit  0
              ---------
              .... LLLL
                   ||||
                   ++++--- Low 4 bits of 1 KiB CHR bank at PPU $1C00
            */
            self.chrBanks[14] = aValue & 0x0F
            self.chrOffsets[7] = Int(UInt16(self.chrBanks[14]) | (UInt16(self.chrBanks[15]) << 4)) * 0x0400
        case 0xE003:
            /*
              $E003
              7  bit  0
              ---------
              ...H HHHH
                 | ||||
                 +-++++-- High 5 bits of 1 KiB CHR bank at PPU $1C00
            */
            self.chrBanks[15] = aValue & 0x1F
            self.chrOffsets[7] = Int(UInt16(self.chrBanks[14]) | (UInt16(self.chrBanks[15]) << 4)) * 0x0400
        case 0xF000:
            // $F000:  IRQ Latch, low 4 bits
            /*
            7  bit  0
            ---------
            .... LLLL
                 ||||
                 ++++- IRQ Latch (reload value)
            */
            self.irqLatchReloadValue = (aValue & 0x0F) | (self.irqLatchReloadValue & 0xF0)
        case 0xF001:
            // $F001:  IRQ Latch, high 4 bits
            /*
            7  bit  0
            ---------
            LLLL ....
            ||||
            ++++------ IRQ Latch (reload value)
            */
            self.irqLatchReloadValue = (aValue & 0xF0) | (self.irqLatchReloadValue & 0x0F)
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
            self.irqEnableAfterAcknowledgement = (aValue >> 0) & 1 == 1
            self.irqEnable = (aValue >> 1) & 1 == 1
            self.irqCycleMode = (aValue >> 2) & 1 == 1
        case 0xF003:
            // $F003:  IRQ Acknowledge
            self.irqEnable = self.irqEnableAfterAcknowledgement
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d CPU write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        switch aAddress {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            return self.chr[self.chrOffsets[Int(bank)] + Int(offset)]
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d PPU read at address: 0x%04X", aAddress)
            return 0
        }
        
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x0400
            let offset = aAddress % 0x0400
            self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
        default:
            os_log("unhandled Mapper_VRC2c_VRC4b_VRC4d PPU write at address: 0x%04X", aAddress)
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        let shouldTriggerIRQ: Bool
        if self.irqCycleMode
        {
            self.irqCounter += 1
            
            if self.irqCounter == 0xFF
            {
                self.irqCounter = self.irqLatchReloadValue
                shouldTriggerIRQ = true
            }
            else
            {
                shouldTriggerIRQ = false
            }
        }
        else
        {
            self.prescaler -= 3
            
            if prescaler <= 0
            {
                self.irqCounter += 1
                
                if self.irqCounter == 0xFF
                {
                    self.irqCounter = self.irqLatchReloadValue
                    shouldTriggerIRQ = true
                }
                else
                {
                    shouldTriggerIRQ = false
                }
            }
            else
            {
                shouldTriggerIRQ = false
            }
        }
        
        return MapperStepResults(requestedCPUInterrupt: shouldTriggerIRQ ? .irq : nil)
    }
}
