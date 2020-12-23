//
//  Mapper_MMC1.swift
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

struct Mapper_MMC1: MapperProtocol
{
    let hasStep: Bool = false
    
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// a variant of the MMC1 where instead of CHR Banks, extra PRG banks are included
    private let isSxROM: Bool
    private var isSxROMHighPRGRangeSelected: Bool
    
    /// this is normally the size of the total PRG blocks, but in the case of switchable 256KB PRG bank sets for SxROM boards, it is the end offset for the current PRG bankset relative to whether the high 256KB selection is active or not
    private var switched256KbPrgBankSetEnd: Int
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    private var shiftRegister: UInt8
    private var control: UInt8
    private var prgMode: UInt8
    private var chrMode: UInt8
    private var prgBank: UInt8
    private var chrBank0: UInt8
    private var chrBank1: UInt8
    private var prgOffsets: [Int]
    private var chrOffsets: [Int]
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }
        
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
        
        let isSxROM = aCartridge.prgBlocks.count > 16
        self.switched256KbPrgBankSetEnd = isSxROM ? self.prg.count / 2 : self.prg.count
        
        self.isSxROM = isSxROM
        
        if let safeState = aState
        {
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.shiftRegister = safeState.uint8s[safe: 0] ?? 0x10
            self.control = safeState.uint8s[safe: 1] ?? 0
            self.prgMode = safeState.uint8s[safe: 2] ?? 0
            self.chrMode = safeState.uint8s[safe: 3] ?? 0
            self.prgBank = safeState.uint8s[safe: 4] ?? 0
            self.chrBank0 = safeState.uint8s[safe: 5] ?? 0
            self.chrBank1 = safeState.uint8s[safe: 6] ?? 0
            self.prgOffsets = [safeState.ints[safe: 0] ?? 0, safeState.ints[safe: 1] ?? 0]
            self.chrOffsets = [safeState.ints[safe: 2] ?? 0, safeState.ints[safe: 3] ?? 0]
            self.isSxROMHighPRGRangeSelected = safeState.bools[safe: 0] ?? false
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.shiftRegister = 0x10
            self.control = 0
            self.prgMode = 0
            self.chrMode = 0
            self.prgBank = 0
            self.chrBank0 = 0
            self.chrBank1 = 0
            self.prgOffsets = [0, 0]
            self.chrOffsets = [0, 0]
            self.isSxROMHighPRGRangeSelected = false
            self.prgOffsets[1] = self.prgBankOffset(index: -1)
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [self.prgOffsets[0], self.prgOffsets[1], self.chrOffsets[0], self.chrOffsets[1]], bools: [self.isSxROMHighPRGRangeSelected], uint8s: [self.shiftRegister, self.control, self.prgMode, self.chrMode, self.prgBank, self.chrBank0, self.chrBank1], chr: self.chr)
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.shiftRegister = newValue.uint8s[safe: 0] ?? 0x10
            self.control = newValue.uint8s[safe: 1] ?? 0
            self.prgMode = newValue.uint8s[safe: 2] ?? 0
            self.chrMode = newValue.uint8s[safe: 3] ?? 0
            self.prgBank = newValue.uint8s[safe: 4] ?? 0
            self.chrBank0 = newValue.uint8s[safe: 5] ?? 0
            self.chrBank1 = newValue.uint8s[safe: 6] ?? 0
            self.prgOffsets = [newValue.ints[safe: 0] ?? 0, newValue.ints[safe: 1] ?? 0]
            self.chrOffsets = [newValue.ints[safe: 2] ?? 0, newValue.ints[safe: 3] ?? 0]
            self.isSxROMHighPRGRangeSelected = newValue.bools[safe: 0] ?? false
            self.chr = newValue.chr
        }
    }
    
    func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
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
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            self.loadRegister(address: aAddress, value: aValue)
        case 0x6000 ..< 0x8000:
            self.sram[Int(aAddress - 0x6000)] = aValue
        default:
            os_log("unhandled Mapper_MMC1 write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        let bank = aAddress / 0x1000
        let offset = aAddress % 0x1000
        let chrBaseOffset: Int = self.chrOffsets[Int(bank)]
        let chrFinalOffset: Int = chrBaseOffset + Int(offset)
        return self.chr[chrFinalOffset]
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        let bank = aAddress / 0x1000
        let offset = aAddress % 0x1000
        self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
    }
    
    mutating func ppuControl(value aValue: UInt8)
    {
        
    }
    
    mutating func ppuMask(value aValue: UInt8)
    {
    
    }

    private mutating func loadRegister(address aAddress: UInt16, value aValue: UInt8)
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

    private mutating func writeRegister(address aAddress: UInt16, value aValue: UInt8)
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
    private mutating func writeControl(value aValue: UInt8)
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
    private mutating func writeCHRBank0(value aValue: UInt8)
    {
        if self.isSxROM
        {
            // use the CHR Bank 0 bits to select an upper 256KB PRG Bank set if appropriate
            /*
             4bit0
             -----
             PSSxC
             ||| |
             ||| +- Select 4 KB CHR RAM bank at PPU $0000 (ignored in 8 KB mode)
             |++--- Select 8 KB PRG RAM bank
             +----- Select 256 KB PRG ROM bank
             */
            self.isSxROMHighPRGRangeSelected = (aValue >> 4 & 1) == 1
            self.switched256KbPrgBankSetEnd = self.isSxROMHighPRGRangeSelected ? self.prg.count : self.prg.count / 2
            self.prgBank = (self.prgBank % 16) + (self.isSxROMHighPRGRangeSelected ? 16 : 0)
        }
        else
        {
            /*
            4bit0
            -----
            CCCCC
            |||||
            +++++- Select 4 KB or 8 KB CHR bank at PPU $0000 (low bit ignored in 8 KB mode)
            */
           self.chrBank0 = aValue
        }
        
        self.updateOffsets()
    }

    // CHR bank 1 (internal, $C000-$DFFF)
    private mutating func writeCHRBank1(value aValue: UInt8)
    {
        if !self.isSxROM
        {
            self.chrBank1 = aValue
        }
        
        self.updateOffsets()
    }

    // PRG bank (internal, $E000-$FFFF)
    /*
    4bit0
    -----
    RPPPP
    |||||
    |++++- Select 16 KB PRG ROM bank 0-15 (low bit ignored in 32 KB mode), or 16-31 if using the upper 256KB range of PRG in SxROM chips.
    +----- PRG RAM chip enable (0: enabled; 1: disabled; ignored on MMC1A)
    */
    private mutating func writePRGBank(value aValue: UInt8)
    {
        self.prgBank = (aValue & 0x0F) + (self.isSxROMHighPRGRangeSelected ? 16 : 0)
        self.updateOffsets()
    }

    private mutating func prgBankOffset(index aIndex: Int) -> Int
    {
        return aIndex >= 0 ? (aIndex * 0x4000) : (max(self.switched256KbPrgBankSetEnd + (aIndex * 0x4000), 0))
    }

    private func chrBankOffset(index aIndex: Int) -> Int
    {
        return aIndex >= 0 ? (aIndex * 0x1000) : (max(self.chr.count + (aIndex * 0x1000), 0))
    }

    // PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
    //                    2: fix first bank at $8000 and switch 16 KB bank at $C000;
    //                    3: fix last bank at $C000 and switch 16 KB bank at $8000)
    // CHR ROM bank mode (0: switch 8 KB at a time
    //                    1: switch two separate 4 KB banks)
    private mutating func updateOffsets()
    {
        switch self.prgMode
        {
        case 0, 1:
            self.prgOffsets[0] = self.prgBankOffset(index: Int(self.prgBank & 0xFE))
            self.prgOffsets[1] = self.prgBankOffset(index: Int(self.prgBank | 0x01))
        case 2:
            self.prgOffsets[0] = 0
            self.prgOffsets[1] = self.prgBankOffset(index: Int(self.prgBank))
        case 3:
            self.prgOffsets[0] = self.prgBankOffset(index: Int(self.prgBank))
            self.prgOffsets[1] = self.prgBankOffset(index: -1)
        default: break
        }
        
        switch self.chrMode
        {
        case 0:
            self.chrOffsets[0] = self.chrBankOffset(index: Int(self.chrBank0 & 0xFE))
            self.chrOffsets[1] = self.chrBankOffset(index: Int(self.chrBank0 | 0x01))
        case 1:
            self.chrOffsets[0] = self.chrBankOffset(index: Int(self.chrBank0))
            self.chrOffsets[1] = self.chrBankOffset(index: Int(self.chrBank1))
        default: break
        }
    }
}

