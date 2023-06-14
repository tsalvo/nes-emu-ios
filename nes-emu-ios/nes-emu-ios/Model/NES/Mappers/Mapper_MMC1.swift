//
//  Mapper_MMC1.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 5/07/22.
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
    // MARK: - Constants
    private static let prgRamSizeInBytes: Int = 32768
    private static let chrRamSizeInBytes: Int = 8192
    private static let requiredPpuCyclesBetweenCpuWrites: Int = 3
    
    // MARK: - Internal Variables
    let hasStep: Bool = true
    let hasExtendedNametableMapping: Bool = false
    var mirroringMode: MirroringMode
    
    // MARK: - Enum Type
    private enum Variant: UInt8 {
        case standard = 0,  // <= 256KB PRG ROM, <= 128KB CHR ROM, 0KB CHR RAM,  8KB PRG RAM
             snrom = 1,     // <= 256KB PRG ROM,      0KB CHR ROM, 8KB CHR RAM,  8KB PRG RAM
             surom = 2,     // <= 512KB PRG ROM,      0KB CHR ROM, 8KB CHR RAM,  8KB PRG RAM
             sorom = 3,     // <= 512KB PRG ROM,      0KB CHR ROM, 8KB CHR RAM, 16KB PRG RAM
             sxrom = 4,     // <= 512KB PRG ROM,      0KB CHR ROM, 8KB CHR RAM, 32KB PRG RAM
             szrom = 5      // <= 512KB PRG ROM,  16-64KB CHR ROM, 0KB CHR RAM, 16KB PRG RAM (rare)
        
        var usesChrRam: Bool {
            switch self
            {
            case .snrom, .surom, .sorom, .sxrom: return true
            default: return false
            }
        }
    }
    
    // MARK: Private Variables
    private let variant: Variant
    
    private let lastPrgBankIndex: UInt8
    private let usesChrRam: Bool
    
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    
    /// 8KB, 16KB, or 32KB of PRG RAM addressible through 0x6000 ... 0x7FFF, using 8KB banks if >= 8KB
    private var prgRam: [UInt8] = [UInt8](repeating: 0, count: prgRamSizeInBytes)
    /// 8KB of CHR RAM addressible through 0x0000 ... 0x1FFF (used on SNROM, SUROM, SOROM, and SXROM variants)
    private var chrRam: [UInt8] = [UInt8](repeating: 0, count: chrRamSizeInBytes)
    
    private var shiftRegister: UInt8
    private var control: UInt8
    private var prgMode: UInt8
    private var prgRamEnabled: Bool
    
    /// false: switch 8 KB at a time; true: switch two separate 4 KB banks)
    private var isChr4KBMode: Bool
    private var prgRamBank: UInt8
    private var prgBank0: UInt8
    private var prgBank1: UInt8
    private var chrBank0: UInt8
    private var chrBank1: UInt8
    private var ppuCyclesSinceLastCPUWrite: UInt8
    private var prgOffsets: [Int] = [Int](repeating: 0, count: 2)
    private var chrOffsets: [Int] = [Int](repeating: 0, count: 2)
    
    private let maxPrgBankLoFor16KBMode: UInt8
    private let max4KBChrBank: UInt8
    
    // MARK: - Life Cycle
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks
        {
            c.append(contentsOf: cBlock)
        }
        
        self.prg = p
        self.chr = c
        
        let variant: Variant
        if aCartridge.chrBlocks.count == 0
        {
            if aCartridge.prgBlocks.count > 16
            {
                // TODO: use iNES 2.0 header to differentiate between SXROM, SORUM, SUROM (different amounts of PRG RAM)
                variant = .sxrom
            }
            else
            {
                variant = .snrom
            }
        }
        else
        {
            if aCartridge.prgBlocks.count > 16 && aCartridge.chrBlocks.count >= 2
            {
                variant = .szrom
            }
            else
            {
                variant = .standard
            }
        }
        self.variant = variant
        self.usesChrRam = variant.usesChrRam
        
        let lastPrgBank: UInt8 = UInt8(aCartridge.prgBlocks.count - 1) & 0x0F
        self.lastPrgBankIndex = lastPrgBank
        self.maxPrgBankLoFor16KBMode = lastPrgBank
        self.max4KBChrBank = UInt8((aCartridge.chrBlocks.count == 0) ? 1 : (aCartridge.chrBlocks.count * 2) - 1)
        
        self.prgRamBank = 0
        self.prgRamEnabled = true
        
        if let safeState = aState,
           safeState.uint8s.count >= Mapper_MMC1.prgRamSizeInBytes + Mapper_MMC1.chrRamSizeInBytes + 9,
           safeState.ints.count >= 4,
           safeState.bools.count >= 2
        {
            let u8ArrayEndOffset = Mapper_MMC1.prgRamSizeInBytes + Mapper_MMC1.chrRamSizeInBytes
            
            self.mirroringMode = MirroringMode.init(rawValue: safeState.mirroringMode) ?? aCartridge.header.mirroringMode
            self.prgRam = [UInt8](safeState.uint8s[0 ..< Mapper_MMC1.prgRamSizeInBytes])
            self.chrRam = [UInt8](safeState.uint8s[Mapper_MMC1.prgRamSizeInBytes ..< u8ArrayEndOffset])
            self.shiftRegister = safeState.uint8s[u8ArrayEndOffset]
            self.control = safeState.uint8s[u8ArrayEndOffset + 1]
            self.prgMode = safeState.uint8s[u8ArrayEndOffset + 2]
            self.prgRamBank = safeState.uint8s[u8ArrayEndOffset + 3]
            self.prgBank0 = safeState.uint8s[u8ArrayEndOffset + 4]
            self.prgBank1 = safeState.uint8s[u8ArrayEndOffset + 5]
            self.chrBank0 = safeState.uint8s[u8ArrayEndOffset + 6]
            self.chrBank1 = safeState.uint8s[u8ArrayEndOffset + 7]
            self.ppuCyclesSinceLastCPUWrite = safeState.uint8s[u8ArrayEndOffset + 8]
            
            self.prgOffsets = [Int](safeState.ints[0 ..< 2])
            self.chrOffsets = [Int](safeState.ints[2 ..< 4])
            
            self.prgRamEnabled = safeState.bools[0]
            self.isChr4KBMode = safeState.bools[1]
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
            self.shiftRegister = 0x10
            self.control = 0
            self.prgMode = 0
            self.prgBank0 = 0
            self.prgBank1 = lastPrgBank
            self.chrBank0 = 0
            self.chrBank1 = 0
            self.ppuCyclesSinceLastCPUWrite = 0
            self.isChr4KBMode = false
            self.prgOffsets[1] = Int(lastPrgBank) * 0x4000
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            var u8: [UInt8] = []
            u8.append(contentsOf: self.prgRam)
            u8.append(contentsOf: self.chrRam)
            u8.append(self.shiftRegister)
            u8.append(self.control)
            u8.append(self.prgMode)
            u8.append(self.prgRamBank)
            u8.append(self.prgBank0)
            u8.append(self.prgBank1)
            u8.append(self.chrBank0)
            u8.append(self.chrBank1)
            u8.append(self.ppuCyclesSinceLastCPUWrite)
            
            var i: [Int] = []
            i.append(contentsOf: self.prgOffsets)
            i.append(contentsOf: self.chrOffsets)
            
            var b: [Bool] = []
            b.append(self.prgRamEnabled)
            b.append(self.isChr4KBMode)
            
            return MapperState(mirroringMode: self.mirroringMode.rawValue, ints: i, bools: b, uint8s: u8, chr: [])
        }
        set
        {
            guard newValue.uint8s.count >= Mapper_MMC1.prgRamSizeInBytes + Mapper_MMC1.chrRamSizeInBytes + 9,
                  newValue.ints.count >= 4,
                  newValue.bools.count >= 2
            else {
                return
            }
            let u8ArrayEndOffset = Mapper_MMC1.prgRamSizeInBytes + Mapper_MMC1.chrRamSizeInBytes
            
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            self.prgRam = [UInt8](newValue.uint8s[0 ..< Mapper_MMC1.prgRamSizeInBytes])
            self.chrRam = [UInt8](newValue.uint8s[Mapper_MMC1.prgRamSizeInBytes ..< u8ArrayEndOffset])
            self.shiftRegister = newValue.uint8s[u8ArrayEndOffset]
            self.control = newValue.uint8s[u8ArrayEndOffset + 1]
            self.prgMode = newValue.uint8s[u8ArrayEndOffset + 2]
            self.prgRamBank = newValue.uint8s[u8ArrayEndOffset + 3]
            self.prgBank0 = newValue.uint8s[u8ArrayEndOffset + 4]
            self.prgBank1 = newValue.uint8s[u8ArrayEndOffset + 5]
            self.chrBank0 = newValue.uint8s[u8ArrayEndOffset + 6]
            self.chrBank1 = newValue.uint8s[u8ArrayEndOffset + 7]
            self.ppuCyclesSinceLastCPUWrite = newValue.uint8s[u8ArrayEndOffset + 8]
            
            self.prgOffsets = [Int](newValue.ints[0 ..< 2])
            self.chrOffsets = [Int](newValue.ints[2 ..< 4])
            
            self.prgRamEnabled = newValue.bools[0]
            self.isChr4KBMode = newValue.bools[1]
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        if self.ppuCyclesSinceLastCPUWrite < UInt8.max
        {
            self.ppuCyclesSinceLastCPUWrite += 1
        }
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
        case 0x6000 ... 0x7FFF: // PRG RAM
            guard self.prgRamEnabled else {
                os_log("Mapper_MMC1 PRG RAM disabled - CPU read 0 at address: 0x%04X", aAddress)
                return 0
            }
            let offset: Int = (Int(self.prgRamBank) * 0x2000) + Int(aAddress - 0x6000)
            return self.prgRam[offset]
        default:
            os_log("unhandled Mapper_MMC1 CPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            self.loadRegister(address: aAddress, value: aValue)
        case 0x6000 ... 0x7FFF: // PRG RAM
            guard self.prgRamEnabled else {
                os_log("Mapper_MMC1 PRG RAM disabled - prevented CPU write at address: 0x%04X", aAddress)
                break
            }
            let offset: Int = (Int(self.prgRamBank) * 0x2000) + Int(aAddress - 0x6000)
            self.prgRam[offset] = aValue
        default:
            os_log("unhandled Mapper_MMC1 CPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            let bank = aAddress / 0x1000
            let offset = aAddress % 0x1000
            let chrBaseOffset: Int = self.chrOffsets[Int(bank)]
            let chrFinalOffset: Int = chrBaseOffset + Int(offset)
            return self.usesChrRam ? self.chrRam[chrFinalOffset] : self.chr[chrFinalOffset]
        default:
            os_log("unhandled Mapper_MMC1 PPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        switch aAddress
        {
        case 0x0000 ... 0x1FFF:
            guard self.usesChrRam else {
                os_log("Mapper_MMC1 attempted PPU write to CHR ROM - prevented PPU write at address: 0x%04X", aAddress)
                break
            }
            let bank = aAddress / 0x1000
            let offset = aAddress % 0x1000
            self.chrRam[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
        default:
            os_log("unhandled Mapper_MMC1 PPU write at address: 0x%04X", aAddress)
            break
        }
    }

    private mutating func loadRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        guard self.ppuCyclesSinceLastCPUWrite >= Mapper_MMC1.requiredPpuCyclesBetweenCpuWrites
            else
        {
            /* ignore CPU writes to $8000-$FFFF that come in too quickly in succession (see comment below)
             https://www.nesdev.org/wiki/MMC1
             When the serial port is written to on consecutive cycles, it ignores every write after the first. In practice, this only happens when the CPU executes read-modify-write instructions, which first write the original value before writing the modified one on the next cycle.[1] This restriction only applies to the data being written on bit 0; the bit 7 reset is never ignored. Bill & Ted's Excellent Adventure does a reset by using INC on a ROM location containing $FF and requires that the $00 write on the next cycle is ignored. Shinsenden, however, uses illegal instruction $7F (RRA abs,X) to set bit 7 on the second write and will crash after selecting the みる (look) option if this reset is ignored.[2] This write-ignore behavior appears to be intentional and is believed to ignore all consecutive write cycles after the first even if that first write does not target the serial port.[3]
             */
            return
        }
        self.ppuCyclesSinceLastCPUWrite = 0
        
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

    private mutating func writeControl(value aValue: UInt8)
    {
        /*
         Control (internal, $8000-$9FFF)
         4bit0
         -----
         CPPMM
         |||||
         |||++- Mirroring (0: one-screen, lower bank; 1: one-screen, upper bank;
         |||               2: vertical; 3: horizontal)
         |++--- PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
         |                         2: fix first bank at $8000 and switch 16 KB bank at $C000;
         |                         3: fix last bank at $C000 and switch 16 KB bank at $8000)
         +----- CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
         */
        self.control = aValue
        self.isChr4KBMode = (aValue >> 4) & 1 == 1
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
        
        switch self.prgMode
        {
        case 0, 1:
            // switch 32 KB at $8000, ignoring low bit of bank number
            self.prgBank0 &= 0x1E
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank0 | 0x01) * 0x4000
        case 2:
            // fix first bank at $8000 and switch 16 KB bank at $C000
            self.prgBank0 &= 0x10
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
        case 3:
            // switch first 16 KB bank at $8000, fix last bank at $C000
            self.prgBank1 &= 0x10
            self.prgBank1 |= self.lastPrgBankIndex
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
        default: break
        }
        
        if self.isChr4KBMode
        {
            // 1: switch two separate 4 KB banks
            self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
            self.chrOffsets[1] = Int(self.chrBank1) * 0x1000
        }
        else
        {
            // 0: switch 8 KB at a time
            self.chrOffsets[0] = Int(self.chrBank0 & 0x1E) * 0x1000
            self.chrOffsets[1] = Int(self.chrBank0 | 0x01) * 0x1000
        }
    }

    // CHR bank 0 (internal, $A000-$BFFF)
    private mutating func writeCHRBank0(value aValue: UInt8)
    {
        switch self.variant
        {
        case .standard:
            /*
            4bit0
            -----
            CCCCC
            |||||
            +++++- Select 4 KB or 8 KB CHR bank at PPU $0000 (low bit ignored in 8 KB mode)
            */
            if self.isChr4KBMode
            {
                self.chrBank0 = aValue & self.max4KBChrBank
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
            }
            else
            {
                self.chrBank0 = aValue & self.max4KBChrBank & 0x1E
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
                self.chrOffsets[1] = Int(self.chrBank0 | 0x01) * 0x1000
            }
            
        case .snrom:
            /*
             4bit0
             -----
             ExxxC
             |   |
             |   +- Select 4 KB CHR RAM bank at PPU $0000 (ignored in 8 KB mode)
             +----- PRG RAM disable (0: enable, 1: open bus)
             */
            self.prgRamEnabled = aValue >> 4 & 1 == 0
            self.chrBank0 = aValue & 0x01
            if self.isChr4KBMode
            {
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
            }
        case .sorom, .surom, .sxrom:
            /*
             4bit0
             -----
             PSSxC
             ||| |
             ||| +- Select 4 KB CHR RAM bank at PPU $0000 (ignored in 8 KB mode)
             |++--- Select 8 KB PRG RAM bank
             +----- Select 256 KB PRG ROM bank
             */
            self.prgBank0 &= 0x0F
            self.prgBank0 |= 0x10 & aValue
            self.prgBank1 &= 0x0F
            self.prgBank1 |= 0x10 & aValue
            self.prgRamBank = aValue >> 2 & 0x03
            self.chrBank0 = aValue & 0x01
            if self.prgMode < 2
            {
                // 0, 1: switch 32 KB at $8000, ignoring low bit of bank number
                self.prgOffsets[0] = Int(self.prgBank0 & 0x1E) * 0x4000
                self.prgOffsets[1] = Int(self.prgBank0 | 0x01) * 0x4000
            }
            else
            {
                // 2: fix first bank at $8000 and switch 16 KB bank at $C000
                // 3: fix last bank at $C000 and switch 16 KB bank at $8000
                self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
                self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
            }
            if self.isChr4KBMode
            {
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
            }
        case .szrom:
            /*
             4bit0
             -----
             RCCCC
             |||||
             |++++- Select 4 KB CHR ROM bank at PPU $0000 (low bit ignored in 8 KB mode)
             +----- Select 8 KB PRG RAM bank
             */
            self.prgRamBank = aValue >> 4 & 1
            if self.isChr4KBMode
            {
                self.chrBank0 = aValue & self.max4KBChrBank
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
            }
            else
            {
                self.chrBank0 = aValue & self.max4KBChrBank & 0x0E
                self.chrOffsets[0] = Int(self.chrBank0) * 0x1000
                self.chrOffsets[1] = Int(self.chrBank0 | 0x01) * 0x1000
            }
        }
    }

    // CHR bank 1 (internal, $C000-$DFFF)
    private mutating func writeCHRBank1(value aValue: UInt8)
    {
        switch self.variant
        {
        case .standard:
            /*
             4bit0
             -----
             CCCCC
             |||||
             +++++- Select 4 KB CHR bank at PPU $1000 (ignored in 8 KB mode)
            */
            if self.isChr4KBMode
            {
                self.chrBank1 = aValue & self.max4KBChrBank
                self.chrOffsets[1] = Int(self.chrBank1) * 0x1000
            }
        case .snrom:
            /*
             4bit0
             -----
             ExxxC
             |   |
             |   +- Select 4 KB CHR RAM bank at PPU $1000 (ignored in 8 KB mode)
             +----- PRG RAM disable (0: enable, 1: open bus) (ignored in 8 KB mode)
             */
            self.prgRamEnabled = aValue >> 4 & 1 == 0
            self.chrBank1 = aValue & 0x01
            if self.isChr4KBMode
            {
                self.chrOffsets[1] = Int(self.chrBank1) * 0x1000
            }
        case .sorom, .surom, .sxrom:
            /*
             4bit0
             -----
             PSSxC
             ||| |
             ||| +- Select 4 KB CHR RAM bank at PPU $1000 (ignored in 8 KB mode)
             |++--- Select 8 KB PRG RAM bank (ignored in 8 KB mode)
             +----- Select 256 KB PRG ROM bank (ignored in 8 KB mode)
             */
            self.prgBank0 &= 0x0F
            self.prgBank0 |= 0x10 & aValue
            self.prgBank1 &= 0x0F
            self.prgBank1 |= 0x10 & aValue
            self.prgRamBank = aValue >> 2 & 0x03
            self.chrBank1 = aValue & 0x01
            if self.isChr4KBMode
            {
                if self.prgMode < 2
                {
                    // 0, 1: switch 32 KB at $8000, ignoring low bit of bank number
                    self.prgOffsets[0] = Int(self.prgBank0 & 0x1E) * 0x4000
                    self.prgOffsets[1] = Int(self.prgBank0 | 0x01) * 0x4000
                }
                else
                {
                    // 2: fix first bank at $8000 and switch 16 KB bank at $C000
                    // 3: fix last bank at $C000 and switch 16 KB bank at $8000
                    self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
                    self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
                }
                self.chrOffsets[1] = Int(self.chrBank1) * 0x1000
            }
        case .szrom:
            /*
             4bit0
             -----
             RCCCC
             |||||
             |++++- Select 4 KB CHR ROM bank at PPU $1000 (ignored in 8 KB mode)
             +----- Select 8 KB PRG RAM bank (ignored in 8 KB mode)
             */
            if self.isChr4KBMode
            {
                self.prgRamBank = aValue >> 4 & 1
                self.chrBank1 = aValue & self.max4KBChrBank
                self.chrOffsets[1] = Int(self.chrBank1) * 0x1000
            }
        }
    }

    private mutating func writePRGBank(value aValue: UInt8)
    {
        /*
         PRG bank (internal, $E000-$FFFF)
         4bit0
         -----
         RPPPP
         |||||
         |++++- Select 16 KB PRG ROM bank (low bit ignored in 32 KB mode)
         +----- MMC1B and later: PRG RAM chip enable (0: enabled; 1: disabled; ignored on MMC1A)
                MMC1A (mapper 155): Bit 3 bypasses fixed bank logic in 16K mode (0: affected; 1: bypassed)
         */
        switch self.prgMode
        {
        case 0, 1:
            // switch 32 KB at $8000, ignoring low bit of bank number
            self.prgBank0 &= 0x10
            self.prgBank0 |= aValue & self.maxPrgBankLoFor16KBMode & 0x0E
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank0 | 0x01) * 0x4000
        case 2:
            // fix first bank at $8000 and switch 16 KB bank at $C000
            self.prgBank0 &= 0x10
            self.prgBank1 &= 0x10
            self.prgBank1 |= aValue & self.maxPrgBankLoFor16KBMode
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
        case 3:
            // switch first 16 KB bank at $8000, fix last bank at $C000
            self.prgBank0 &= 0x10
            self.prgBank0 |= aValue & self.maxPrgBankLoFor16KBMode
            self.prgBank1 &= 0x10
            self.prgBank1 |= self.lastPrgBankIndex
            self.prgOffsets[0] = Int(self.prgBank0) * 0x4000
            self.prgOffsets[1] = Int(self.prgBank1) * 0x4000
        default: break
        }
    }
}

