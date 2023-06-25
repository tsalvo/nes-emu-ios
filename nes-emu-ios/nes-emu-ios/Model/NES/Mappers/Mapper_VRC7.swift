//
//  Mapper_VRC7.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 5/01/22.
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

struct Mapper_VRC7: MapperProtocol
{
    static private let scalerPreset: Int = 341 * 3 // TODO: this should be 341
    static private let scalerDelta: Int = 3
    
    let hasStep: Bool = true
    
    let hasExtendedNametableMapping: Bool = false
    
    private(set) var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 3x 8 KB switchable PRG-ROM banks at $8000-$9FFF, $A000-$BFFF and $C000-$DFFF, plus $E000-$FFFF fixed to the last bank
    private var prgOffsets: [Int] = [Int](repeating: 0, count: 4)
    
    /// 8x 1 KB switchable CHR-ROM banks
    private var chrOffsets: [Int] = [Int](repeating: 0, count: 8)
    
    /// 8 KB PRG-RAM bank, fixed at at $6000-$7FFF
    private var sram: [UInt8] = [UInt8](repeating: 0, count: 8192)
    
    private var audioEnabled: Bool = true
    
    private var irqEnableAfterAcknowledgement: Bool = false
    
    private var irqEnable: Bool = false
    
    private var irqCycleMode: Bool = false
    
    /// IRQ Latch Reload Value
    private var irqLatch: UInt8 = 0
    
    private var irqCounter: UInt8 = 0
    
    private var irqScaler: Int = Mapper_VRC7.scalerPreset
    
    private var irqLine: Bool = false
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState,
           safeState.uint8s.count >= 8194,
           safeState.bools.count >= 5,
           safeState.ints.count >= 13,
           safeState.chr.count == 262144
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.sram = [UInt8](safeState.uint8s[0 ..< 8192])
            self.irqLatch = safeState.uint8s[8192]
            self.irqCounter = safeState.uint8s[8193]
            self.audioEnabled = safeState.bools[0]
            self.irqEnableAfterAcknowledgement = safeState.bools[1]
            self.irqEnable = safeState.bools[2]
            self.irqCycleMode = safeState.bools[3]
            self.irqLine = safeState.bools[4]
            self.prgOffsets = [Int](safeState.ints[0 ..< 4])
            self.chrOffsets = [Int](safeState.ints[4 ..< 12])
            self.irqScaler = safeState.ints[12]
            self.chr = safeState.chr
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            
            for c in aCartridge.chrBlocks
            {
                self.chr.append(contentsOf: c)
            }
            
            while self.chr.count < 262144
            {
                self.chr.append(contentsOf: [UInt8](repeating: 0, count: 8192))
            }
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
            var u8: [UInt8] = []
            u8.append(contentsOf: self.sram)
            u8.append(self.irqLatch)
            u8.append(self.irqCounter)
            
            var b: [Bool] = []
            b.append(self.audioEnabled)
            b.append(self.irqEnableAfterAcknowledgement)
            b.append(self.irqEnable)
            b.append(self.irqCycleMode)
            b.append(self.irqLine)
            
            var i: [Int] = []
            i.append(contentsOf: self.prgOffsets)
            i.append(contentsOf: self.chrOffsets)
            i.append(self.irqScaler)
            
            return MapperState(mirroringMode: self.mirroringMode.rawValue, ints: i, bools: b, uint8s: u8, chr: self.chr)
        }
        set
        {
            guard newValue.uint8s.count >= 8194,
                  newValue.bools.count >= 5,
                  newValue.ints.count >= 13,
                  newValue.chr.count == 262144
            else
            {
                return
            }
            
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.sram = [UInt8](newValue.uint8s[0 ..< 8192])
            self.irqLatch = newValue.uint8s[8192]
            self.irqCounter = newValue.uint8s[8193]
            self.audioEnabled = newValue.bools[0]
            self.irqEnableAfterAcknowledgement = newValue.bools[1]
            self.irqEnable = newValue.bools[2]
            self.irqCycleMode = newValue.bools[3]
            self.irqLine = newValue.bools[4]
            self.prgOffsets = [Int](newValue.ints[0 ..< 4])
            self.chrOffsets = [Int](newValue.ints[4 ..< 12])
            self.irqScaler = newValue.ints[12]
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
        case 0x8000:
            /*
             PRG Select 0
             7  bit  0
             ---------
             ..PP PPPP
               || ||||
               ++-++++- Select 8 KB PRG ROM at $8000
             */
            self.prgOffsets[0] = Int(aValue & 0x3F) * 0x2000
        case 0x8008, 0x8010:
            /*
             PRG Select 1
             7  bit  0
             ---------
             ..PP PPPP
               || ||||
               ++-++++- Select 8 KB PRG ROM at $A000
             */
            self.prgOffsets[1] = Int(aValue & 0x3F) * 0x2000
        case 0x9000:
            /*
             PRG Select 2
             7  bit  0
             ---------
             ..PP PPPP
               || ||||
               ++-++++- Select 8 KB PRG ROM at $C000
             */
            self.prgOffsets[2] = Int(aValue & 0x3F) * 0x2000
        case 0x9010:
            /* Audio Register Select
            7......0
            VVVVVVVV
            ++++++++- The 8-bit internal register to select for use with $9030
            */
            // TODO: implement audio https://www.nesdev.org/wiki/VRC7_audio
            break
        case 0x9030:
            /* Audio Register Write
            7......0
            VVVVVVVV
            ++++++++- The 8-bit value to write to the internal register selected with $9010
            */
            // TODO: implement audio https://www.nesdev.org/wiki/VRC7_audio
            break
        case 0xA000:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 0 at $0000-$03FF
             */
            self.chrOffsets[0] = Int(aValue) * 0x0400
        case 0xA008, 0xA010:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 1 at $0400-$07FF
             */
            self.chrOffsets[1] = Int(aValue) * 0x0400
        case 0xB000:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 2 at $0800-$0BFF
             */
            self.chrOffsets[2] = Int(aValue) * 0x0400
        case 0xB008, 0xB010:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 3 at $0C00-$0FFF
             */
            self.chrOffsets[3] = Int(aValue) * 0x0400
        case 0xC000:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 4 at $1000-$13FF
             */
            self.chrOffsets[4] = Int(aValue) * 0x0400
        case 0xC008, 0xC010:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 5 at $1400-$17FF
             */
            self.chrOffsets[5] = Int(aValue) * 0x0400
        case 0xD000:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 6 at $1800-$1BFF
             */
            self.chrOffsets[6] = Int(aValue) * 0x0400
        case 0xD008, 0xD010:
            /*
             7  bit  0
             ---------
             CCCC CCCC
             |||| ||||
             ++++-++++- Select 1 KB CHR bank 7 at $1C00-$1FFF
             */
            self.chrOffsets[7] = Int(aValue) * 0x0400
        case 0xE000:
            /*
             Mirroring Control
             7  bit  0
             ---------
             RS.. ..MM
             ||     ||
             ||     ++- Mirroring (0: vertical; 1: horizontal;
             ||                        2: one-screen, lower bank; 3: one-screen, upper bank)
             |+-------- Silence expansion sound if set
             +--------- WRAM enable (1: enable WRAM, 0: protect)
             */
            self.audioEnabled = (aValue >> 6) & 1 == 0
            switch aValue & 0x03
            {
            case 0: self.mirroringMode = .vertical
            case 1: self.mirroringMode = .horizontal
            case 2: self.mirroringMode = .single0
            case 3: self.mirroringMode = .single1
            default: break
            }
        case 0xE008, 0xE010:
            // $F000:  IRQ Latch
            /*
             7  bit  0
             ---------
             .... LLLL
                  ||||
                  ++++- IRQ Latch (reload value)
             */
            self.irqLatch = aValue
        case 0xF000:
            // $F000:  IRQ Control
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
                self.irqScaler = Mapper_VRC7.scalerPreset
            }

        case 0xF008, 0xF010:
            // $F008:  IRQ Acknowledge
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
            let bankOffset: Int = self.chrOffsets[Int(aAddress / 0x0400)]
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
        case 0x0000 ... 0x1FFF:
            let bankOffset: Int = self.chrOffsets[Int(aAddress / 0x0400)]
            let offset = Int(aAddress) % 0x0400
            self.chr[bankOffset + offset] = aValue
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
            self.irqScaler -= Mapper_VRC7.scalerDelta
            
            if self.irqScaler <= 0
            {
                self.irqScaler += Mapper_VRC7.scalerPreset
                
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
