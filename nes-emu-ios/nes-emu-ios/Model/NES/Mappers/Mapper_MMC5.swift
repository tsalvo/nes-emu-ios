//
//  Mapper_MMC5.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 7/1/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

/// https://wiki.nesdev.com/w/index.php/MMC5

struct Mapper_MMC5: MapperProtocol
{
    enum NameTableMode: UInt8
    {
        case
        /// On-board VRAM page 0
        onboardVRAMPage0 = 0,
        
        /// On-board VRAM page 1
        onboardVRAMPage1 = 1,
        
        /// Internal Expansion RAM, only if the Extended RAM mode allows it ($5104 is 00/01); otherwise, the nametable will read as all zeros
        internalExpansionRAM = 2,
        
        /// Fill-mode data
        fillModeData = 3
    }
    
    let hasStep: Bool = true
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 0 - 3
    private var prgMode: UInt8 = 2
    
    /// 0 - 3
    private var chrMode: UInt8 = 3
    
    /// 0 - 3
    private var extendedRamMode: UInt8 = 0
    
    /// the tile number to use when the NameTableMode is fillmodeData.  controlled by register 0x5106
    private var fillModeTile: UInt8 = 0
    
    /// 0 - 3: attribute bits to use when the NameTableMode is fillmodeData.  controller by register 0x5107
    private var fillModeColor: UInt8 = 0
    
    /// NameTable modes for PPU $2000-$23FF, $2400-$27FF, $2800-$2BFF, and $2C00-$2FFF
    private var nameTableModes: [NameTableMode] = [NameTableMode].init(repeating: NameTableMode.onboardVRAMPage0, count: 4)
    
    private var verticalSplitScreenSide: Bool = false
    private var verticalSplitScreenMode: Bool = false
    
    /// 0 - 31
    private var verticalSplitStartStopTile: UInt8 = 0
    
    /// 0 - 15 - select an 8KB range of SRAM within the 128KB total SRAM
    private var sramBank: UInt8 = 0
    
    /// 128KB of SRAM addressible through 0x6000 ... 0x7FFF, 8KB bank-switched
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 1024 * 128)
    
    private var last2xxxReadAddress: UInt16 = 0
    
    private var inFrameFlag: Bool = false
    
    /// becomes set at any time that the internal scanline counter matches the value written to register $5203
    private var pendingIRQFlag: Bool = false
    
    /// scanline counter
    private var counter: UInt8 = 0
    
    private var prgOffsets: [Int] = [Int].init(repeating: 0, count: 4)
    private var chrOffsets: [Int] = [Int].init(repeating: 0, count: 8)
    
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
        
        self.prgOffsets[0] = (aCartridge.prgBlocks.count - 1) * 16384
        self.prgOffsets[1] = (aCartridge.prgBlocks.count - 1) * 16384
        self.prgOffsets[2] = (aCartridge.prgBlocks.count - 1) * 16384 + 8192
        self.prgOffsets[3] = (aCartridge.prgBlocks.count - 1) * 16384
    }
    
    /// read a given mapper address from the CPU (must be an address in the range 0x6000 ... 0xFFFF)
    mutating func cpuRead(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            switch self.prgMode
            {
            case 0:
                /// 32KB switchable PRG ROM
                return self.prg[self.prgOffsets[0] + Int(aAddress - 0x8000)]
            case 1:
                /// $8000-$BFFF: 16 KB switchable PRG ROM / RAM bank
                /// $C000-$FFFF: 16 KB switchable PRG ROM bank
                let bank: Int = Int(aAddress - 0x8000) / 0x4000
                let offset: Int = Int(aAddress % 0x4000)
                return self.prg[self.prgOffsets[bank] + offset]
            case 2:
                /// CPU $8000-$BFFF: 16 KB switchable PRG ROM/RAM bank
                /// CPU $C000-$DFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $E000-$FFFF: 8 KB switchable PRG ROM bank
                switch aAddress
                {
                case 0x8000 ... 0xBFFF:
                    return self.prg[self.prgOffsets[0] + Int(aAddress - 0x8000)]
                default: /// 0xC000 ... 0xFFFF
                    let bank: Int = 1 + (Int(aAddress - 0xC000) / 0x2000)
                    let offset: Int = Int(aAddress % 0x2000)
                    return self.prg[self.prgOffsets[bank] + offset]
                }
            case 3:
                /// CPU $8000-$9FFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $A000-$BFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $C000-$DFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $E000-$FFFF: 8 KB switchable PRG ROM bank
                let bank: Int = Int(aAddress - 0x8000) / 0x2000
                let offset: Int = Int(aAddress % 0x2000)
                return self.prg[self.prgOffsets[bank] + offset]
            default:
                return 0
            }
        case 0x5204:
            /*
             7  bit  0
             ---- ----
             SVxx xxxx  MMC5A default power-on value = $00
             ||
             |+-------- "In Frame" flag
             +--------- Scanline IRQ Pending flag
             */
            let result: UInt8 = (self.pendingIRQFlag ? 0b00000001 : 0) + (self.inFrameFlag ? 0b00000010 : 0)
            self.pendingIRQFlag = false
            self.inFrameFlag = false
            os_log("CPU Read Scanline IRQ Status (0x5204) -> %@", result.binaryString)
            return result
        case 0x6000 ... 0x7FFF:
            return self.sram[(Int(self.sramBank) * 0x2000) + (Int(aAddress) - 0x6000)]
        default:
            os_log("unhandled Mapper_MMC5 CPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
            case 0x8000 ... 0xFFFF:
            switch self.prgMode
            {
            case 0:
                /// 32KB switchable PRG ROM
                self.prg[self.prgOffsets[0] + Int(aAddress - 0x8000)] = aValue
            case 1:
                /// $8000-$BFFF: 16 KB switchable PRG ROM / RAM bank
                /// $C000-$FFFF: 16 KB switchable PRG ROM bank
                let bank: Int = Int(aAddress - 0x8000) / 0x4000
                let offset: Int = Int(aAddress % 0x4000)
                self.prg[self.prgOffsets[bank] + offset] = aValue
            case 2:
                /// CPU $8000-$BFFF: 16 KB switchable PRG ROM/RAM bank
                /// CPU $C000-$DFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $E000-$FFFF: 8 KB switchable PRG ROM bank
                switch aAddress
                {
                case 0x8000 ... 0x9FFF:
                    self.prg[self.prgOffsets[0] + Int(aAddress - 0x8000)] = aValue
                default: /// 0xC000 ... 0xFFFF
                    let bank: Int = 1 + (Int(aAddress - 0xC000) / 0x2000)
                    let offset: Int = Int(aAddress % 0x2000)
                    self.prg[self.prgOffsets[bank] + offset] = aValue
                }
            case 3:
                /// CPU $8000-$9FFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $A000-$BFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $C000-$DFFF: 8 KB switchable PRG ROM/RAM bank
                /// CPU $E000-$FFFF: 8 KB switchable PRG ROM bank
                let bank: Int = Int(aAddress - 0x8000) / 0x2000
                let offset: Int = Int(aAddress % 0x2000)
                self.prg[self.prgOffsets[bank] + offset] = aValue
            default:
                break
            }
        case 0x6000 ... 0x7FFF:
            self.sram[(Int(self.sramBank) * 0x2000) + (Int(aAddress) - 0x6000)] = aValue
        case 0x5100:
            /* PRG MODE
             7  bit  0
             ---- ----
             xxxx xxPP
                    ||
                    ++- Select PRG banking mode
             */
            self.prgMode = aValue & 0x03
            os_log("PRG Mode: %@ (%d)", aValue.binaryString, self.prgMode)
        case 0x5101:
            /* PRG MODE
             7  bit  0
             ---- ----
             xxxx xxCC
                    ||
                    ++- Select CHR banking mode
             */
            
            self.chrMode = aValue & 0x03
            os_log("CHR Mode: %@ (%d)", aValue.binaryString, self.chrMode)
        case 0x5102:
            /*
            7  bit  0
            ---- ----
            xxxx xxWW
                   ||
                   ++- RAM protect 1
            */
            os_log("PRG RAM Protect 1: %@", aValue.binaryString)
        case 0x5103:
            /*
            7  bit  0
            ---- ----
            xxxx xxWW
                   ||
                   ++- RAM protect 2
            */
            os_log("PRG RAM Protect 2: %@", aValue.binaryString)
        case 0x5104:
            /*
            7  bit  0
            ---- ----
            xxxx xxXX
                   ||
                   ++- Specify extended RAM usage
             */
            /// 0 - Use as extra nametable (possibly for split mode)
            /// 1 - Use as extended attribute data (can also be used as extended nametable)
            /// 2 - Use as ordinary RAM
            /// 3 - Use as ordinary RAM, write protected
            self.extendedRamMode = aValue & 0x03
            os_log("Extended RAM Mode: %@, (%d)", aValue.binaryString, self.extendedRamMode)
        case 0x5105:
            /*
             7  bit  0
             ---- ----
             DDCC BBAA
             |||| ||||
             |||| ||++- Select nametable at PPU $2000-$23FF
             |||| ++--- Select nametable at PPU $2400-$27FF
             ||++------ Select nametable at PPU $2800-$2BFF
             ++-------- Select nametable at PPU $2C00-$2FFF
             */
            /// Nametable values:
            /// 0 - On-board VRAM page 0
            /// 1 - On-board VRAM page 1
            /// 2 - Internal Expansion RAM, only if the Extended RAM mode allows it ($5104 is 00/01); otherwise, the nametable will read as all zeros,
            /// 3 - Fill-mode data
            self.nameTableModes[0] = NameTableMode.init(rawValue: aValue & 0x03) ?? NameTableMode.onboardVRAMPage0
            self.nameTableModes[1] = NameTableMode.init(rawValue: (aValue >> 2) & 0x03) ?? NameTableMode.onboardVRAMPage0
            self.nameTableModes[2] = NameTableMode.init(rawValue: (aValue >> 4) & 0x03) ?? NameTableMode.onboardVRAMPage0
            self.nameTableModes[3] = NameTableMode.init(rawValue: (aValue >> 6) & 0x03) ?? NameTableMode.onboardVRAMPage0
            os_log("NameTable Mapping (0x%04X): %@, 0x2000-23FF = %@, 0x2400-27FF = %@, 0x2800-2BFF = %@, 0x2C00-2FFF = %@", aAddress, aValue.binaryString, String(describing: self.nameTableModes[0]),  String(describing: self.nameTableModes[1]), String(describing: self.nameTableModes[2]), String(describing: self.nameTableModes[3]))
        case 0x5106:
            /// All eight bits specify the tile number to use for fill-mode nametable
            self.fillModeTile = aValue
            os_log("Fill-Mode Tile (0x%04X): %@", aAddress, aValue.binaryString)
        case 0x5107:
            /*
             7  bit  0
             ---- ----
             xxxx xxAA
                    ||
                    ++- Specify attribute bits to use for fill-mode nametable
             */
            self.fillModeColor = aValue & 0x03
            os_log("Fill-Mode Color (0x%04X): %@ (%d)", aAddress, aValue.binaryString, self.fillModeColor)
        case 0x5113 ... 0x5117:
            os_log("PRG Bank Switch (0x%04X): %@", aAddress, aValue.binaryString)
        case 0x5120 ... 0x512B:
            os_log("CHR Bank Switch (0x%04X): %@", aAddress, aValue.binaryString)
        case 0x5130:
            /*
             7  bit  0
             ---- ----
             xxxx xxBB
                    ||
                    ++- Upper bits for subsequent CHR bank writes
             */
            os_log("Upper CHR Bank bits (0x%04X): %@", aAddress, aValue.binaryString)
        case 0x5200:
            /*
             7  bit  0
             ---- ----
             ESxW WWWW
             || | ||||
             || +-++++- Specify vertical split start/stop tile
             |+-------- Specify vertical split screen side (0:left; 1:right)
             +--------- Enable vertical split mode
             */
            
            self.verticalSplitScreenSide = (aValue >> 6) & 1 == 1
            self.verticalSplitScreenMode = (aValue >> 7) & 1 == 1
            self.verticalSplitStartStopTile = aValue & 0x1F
            os_log("Vertical Split Mode (0x%04X): %@", aAddress, aValue.binaryString)
        default:
            os_log("unhandled Mapper_MMC5 CPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x0000 ...  0x1FFF:
            switch self.chrMode
            {
            case 0:
                /// $0000-$1FFF: 8 KB switchable CHR bank
                return self.chr[self.chrOffsets[0] + Int(aAddress)]
            case 1:
                /// $0000-$0FFF: 4 KB switchable CHR bank
                /// $1000-$1FFF: 4 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x1000)
                let offset: Int = Int(aAddress % 0x1000)
                return self.chr[self.chrOffsets[bank] + offset]
            case 2:
                /// $0000-$07FF: 2 KB switchable CHR bank
                /// $0800-$0FFF: 2 KB switchable CHR bank
                /// $1000-$17FF: 2 KB switchable CHR bank
                /// $1800-$1FFF: 2 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x0800)
                let offset: Int = Int(aAddress % 0x0800)
                return self.chr[self.chrOffsets[bank] + offset]
            case 3:
                /// $0000-$03FF: 1 KB switchable CHR bank
                /// $0400-$07FF: 1 KB switchable CHR bank
                /// $0800-$0BFF: 1 KB switchable CHR bank
                /// $0C00-$0FFF: 1 KB switchable CHR bank
                /// $1000-$13FF: 1 KB switchable CHR bank
                /// $1400-$17FF: 1 KB switchable CHR bank
                /// $1800-$1BFF: 1 KB switchable CHR bank
                /// $1C00-$1FFF: 1 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x0400)
                let offset: Int = Int(aAddress % 0x0400)
                return self.chr[self.chrOffsets[bank] + offset]
            default:
                return 0
            }
        case 0x2000 ... 0x2FFF:
            self.last2xxxReadAddress = aAddress
            return 0
        default:
            os_log("unhandled Mapper_MMC5 PPU read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
            case 0x0000 ...  0x1FFF:
            switch self.chrMode
            {
            case 0:
                /// $0000-$1FFF: 8 KB switchable CHR bank
                self.chr[self.chrOffsets[0] + Int(aAddress)] = aValue
            case 1:
                /// $0000-$0FFF: 4 KB switchable CHR bank
                /// $1000-$1FFF: 4 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x1000)
                let offset: Int = Int(aAddress % 0x1000)
                self.chr[self.chrOffsets[bank] + offset] = aValue
            case 2:
                /// $0000-$07FF: 2 KB switchable CHR bank
                /// $0800-$0FFF: 2 KB switchable CHR bank
                /// $1000-$17FF: 2 KB switchable CHR bank
                /// $1800-$1FFF: 2 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x0800)
                let offset: Int = Int(aAddress % 0x0800)
                self.chr[self.chrOffsets[bank] + offset] = aValue
            case 3:
                /// $0000-$03FF: 1 KB switchable CHR bank
                /// $0400-$07FF: 1 KB switchable CHR bank
                /// $0800-$0BFF: 1 KB switchable CHR bank
                /// $0C00-$0FFF: 1 KB switchable CHR bank
                /// $1000-$13FF: 1 KB switchable CHR bank
                /// $1400-$17FF: 1 KB switchable CHR bank
                /// $1800-$1BFF: 1 KB switchable CHR bank
                /// $1C00-$1FFF: 1 KB switchable CHR bank
                let bank: Int = Int(aAddress / 0x0400)
                let offset: Int = Int(aAddress % 0x0400)
                self.chr[self.chrOffsets[bank] + offset] = aValue
            default: break
            }
        default:
            os_log("unhandled Mapper_MMC5 PPU write at address: 0x%04X", aAddress)
            break
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        //os_log("Mapper_MMC5 step: PPU Cycle = %d, Scanline = %d", aMapperStepInput.ppuCycle, aMapperStepInput.ppuScanline)
        
        self.pendingIRQFlag = aMapperStepInput.ppuCycle == 0
        self.inFrameFlag = aMapperStepInput.ppuScanline < 240
    
        return MapperStepResults(shouldTriggerIRQOnCPU: false)
    }
    
    private func handleScanline() -> Bool
    {
        return false
//        let shouldTriggerIRQ: Bool
//
//        if self.counter == 0
//        {
//            self.counter = self.reload
//            shouldTriggerIRQ = false
//        }
//        else
//        {
//            self.counter -= 1
//            shouldTriggerIRQ = self.counter == 0 && self.irqEnable
//        }
//
//        return shouldTriggerIRQ
    }
}
