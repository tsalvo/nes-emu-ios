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
    
    private var extendedRam: [UInt8] = [UInt8].init(repeating: 0, count: 1024)
    
    /// the last address read from the PPU the range 0x2000 - 0x2FFF
    private var last2xxxReadAddress: UInt16 = 0
    /// the number of consecutive PPU reads of a single address in the range 0x2000 - 0x2FFF
    private var ppu2xxxConsecutiveReadCount: UInt8 = 0
    private var reg5203Value: UInt8 = 0
    private var scanline: UInt8 = 0
    private var inFrameFlag: Bool = false
    private var ppuIsReading: Bool = false
    private var idleCount: Int = 0
    private var irqEnableFlag: Bool = false
    private var upperChrBankSet: Bool = true
    private var ppuFetchesThisScanline: Int = 0
    private var sprite8x16ModeEnable: Bool = false
    private var ppuCtrl: UInt8 = 0
    private var ppuMask: UInt8 = 0
    private var lastScanline: Int = 0
    
    private var selectedPrgRamChip: UInt8 = 0
    
    /// becomes set at any time that the internal scanline counter matches the value written to register $5203
    private var pendingIRQFlag: Bool = false
    
    private var prgOffsets: [Int] = [Int].init(repeating: 0, count: 4)
    private var chrOffsets: [Int] = [Int].init(repeating: 0, count: 12)
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        // TODO: implement restoration from MapperState once MMC5 mapper is working correctly
        self.mirroringMode = aCartridge.header.mirroringMode
        for p in aCartridge.prgBlocks
        {
            self.prg.append(contentsOf: p)
        }

        for c in aCartridge.chrBlocks
        {
            self.chr.append(contentsOf: c)
        }
        
        self.prgOffsets[0] = 0//(aCartridge.prgBlocks.count - 1) * 16384
        self.prgOffsets[1] = 0//(aCartridge.prgBlocks.count - 1) * 16384
        self.prgOffsets[2] = (aCartridge.prgBlocks.count - 1) * 16384 + 8192
        self.prgOffsets[3] = 0//(aCartridge.prgBlocks.count - 1) * 16384
    }
    
    // TODO: implement retrieval of MapperState, and restoration from MapperState, once MMC5 mapper is working correctly
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: self.mirroringMode.rawValue, ints: [], bools: [], uint8s: [], chr: self.chr)
        }
        set
        {
            self.mirroringMode = MirroringMode.init(rawValue: newValue.mirroringMode) ?? self.mirroringMode
            
            self.chr = newValue.chr
        }
    }
    
    /// read a given mapper address from the CPU (must be an address in the range 0x6000 ... 0xFFFF)
    mutating func cpuRead(address aAddress: UInt16) -> UInt8
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            if aAddress == 0xFFFA || aAddress == 0xFFFB
            {
                self.inFrameFlag = false
                self.last2xxxReadAddress = 0
            }
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
        case 0x5203:
            return self.reg5203Value
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
            os_log("CPU Read Scanline IRQ Status (0x5204) -> %@", result.binaryString)
            return result
        case 0x5C00 ... 0x5FFF:
            if self.extendedRamMode == 0x2 || self.extendedRamMode == 0x3
            {
                return self.extendedRam[Int(aAddress - 0x5C00)]
            }
            else
            {
                return self.sram[Int(aAddress)]
            }
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
            os_log("unhandled Mapper_MMC5 CPU write at address (APU?) (unimplemented): 0x%04X -> %@", aAddress,  aValue.binaryString)
        case 0x5000 ... 0x5015:
            os_log("unhandled Mapper_MMC5 CPU write at address (APU?) (unimplemented): 0x%04X -> %@", aAddress,  aValue.binaryString)
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
//            self.sramBank = aValue & 03
            os_log("PRG RAM Protect 1 (unimplemented): %@", aValue.binaryString)
        case 0x5103:
            /*
            7  bit  0
            ---- ----
            xxxx xxWW
                   ||
                   ++- RAM protect 2
            */
            os_log("PRG RAM Protect 2 (unimplemented): %@", aValue.binaryString)
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
            /*
             7  bit  0
             ---- ----
             RAAA AaAA
             |||| ||||
             |||| |||+- PRG ROM/RAM A13
             |||| ||+-- PRG ROM/RAM A14
             |||| |+--- PRG ROM/RAM A15, also selecting between PRG RAM /CE 0 and 1
             |||| +---- PRG ROM/RAM A16
             |||+------ PRG ROM A17
             ||+------- PRG ROM A18
             |+-------- PRG ROM A19
             +--------- RAM/ROM toggle (0: RAM; 1: ROM) (registers $5114-$5116 only)
             */
            ///RAM is always mapped at $6000-$7FFF, and the bit $5113.7 is ignored. ROM is always mapped at the bank controlled by register $5117, and the bit $5117.7 is ignored. This makes it impossible to map RAM at interrupt vectors in any mode.
            ///Modes 0-2 : The bankswitching registers always hold a value of 8kb bank index numbers. When selecting banks of a "larger" size (16 kb or 32kb), the low bits in the bankswitching register are ignored. In other words, the address lines from the CPU are passed through the mapper directly to the PRG-ROM chip.
            ///Games seem to expect $5117 to be $FF at power on. All games have their reset vector in the last bank of PRG ROM, and the vector points to an address greater than or equal to $E000.
            switch aAddress
            {
            case 0x5113:
                self.sramBank = aValue & 0x7F
                //self.selectedPrgRamChip = ((aValue >> 2) & 0x1)
                os_log("PRG RAM Bank Switch (0x%04X) %d: %@", aAddress, aValue.binaryString)
            case 0x5114:
                /// prg mode 2: (unused)
                os_log("PRG Bank Switch (0x%04X) (unimplemented) %d: %@", aAddress, aValue.binaryString)
                break
            case 0x5115:
                switch self.prgMode
                {
                /// prg mode 2: CPU $8000-$BFFF: 16 KB switchable PRG ROM/RAM bank
                case 2:
                    let bank = Int(aValue & 0x7F)
                    self.prgOffsets[0] = 8192 * bank
                    //self.prgOffsets[1] = 8192 * bank + 8192
                    os_log("PRG Bank Switch (0x%04X) PRG Mode: %d, 16KB bank: %d, %@", aAddress, self.prgMode, bank, aValue.binaryString)
                default:
                    os_log("PRG Bank Switch (0x%04X) (unimplemented) %@", aAddress, aValue.binaryString)
                }
            case 0x5116:
                switch self.prgMode
                {
                /// prg mode 2: CPU $C000-$DFFF: 8 KB switchable PRG ROM/RAM bank
                case 2:
                    let bank: Int = Int(aValue) & 0x7F
                    self.prgOffsets[1] = 8192 * bank
                    os_log("PRG Bank Switch (0x%04X) PRG Mode: %d, 8KB bank: %d, %@", aAddress, self.prgMode, bank, aValue.binaryString)
                default:
                    os_log("PRG Bank Switch (0x%04X) (unimplemented) %@", aAddress, aValue.binaryString)
                }
            case 0x5117:
                /// prg mode 2: CPU $E000-$FFFF: 8 KB switchable PRG ROM bank
                let bank: Int = Int(aValue) & 0x7F
                self.prgOffsets[2] = 8192 * bank
                os_log("PRG Bank Switch (0x%04X) (unimplemented): %@", aAddress, aValue.binaryString)
            default: break
            }
            
        
        case 0x5120 ... 0x5127:
            switch self.chrMode
            {
            case 3:
                self.chrOffsets[Int(aAddress - 0x5120)] = Int(max(0, min(127, aValue))) * 1024
                os_log("CHR Bank Switch (0x%04X) CHR Mode: %d: %@", aAddress, self.chrMode, aValue.binaryString)
            default: os_log("CHR Bank Switch  CHR Mode: %d: (0x%04X) (unimplemented): %@", aAddress, self.chrMode, aValue.binaryString)
            }
        case 0x5128 ... 0x512B:
            if self.sprite8x16ModeEnable
            {
                switch self.chrMode
                {
                case 3:
                    self.chrOffsets[Int(aAddress - 0x5120)] = Int(max(0, min(127, aValue))) * 1024
                    os_log("CHR Bank Switch (0x%04X) CHR Mode: %d: %@", aAddress, self.chrMode, aValue.binaryString)
                default: os_log("CHR Bank Switch (0x%04X) (unimplemented): %@", aAddress, aValue.binaryString)
                }
            }

        case 0x5130:
            /*
             7  bit  0
             ---- ----
             xxxx xxBB
                    ||
                    ++- Upper bits for subsequent CHR bank writes
             */
            os_log("Upper CHR Bank bits (0x%04X) (unimplemented): %@", aAddress, aValue.binaryString)
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
        case 0x5203:
            self.reg5203Value = aValue
            os_log("IRQ Scanline Compare Value (0x%04X): %@", aAddress, aValue.binaryString)
        case 0x5204:
            /*
            7  bit  0
            ---- ----
            Exxx xxxx
            |
            +--------- Scanline IRQ Enable flag (1=enable)
            */
            self.irqEnableFlag = (aValue >> 7) & 1 == 1
            os_log("IRQ Enable Flag (0x%04X): %@", aAddress, aValue.binaryString)
        default:
            os_log("unhandled Mapper_MMC5 CPU write at address (unimplemented): 0x%04X", aAddress)
            break
        }
        
        if aAddress >= 0x5C00 && aAddress <= 0x5FFF
        {
            if self.extendedRamMode != 0x3
            {
                self.sram[Int(aAddress)] = aValue
                self.extendedRam[Int(aAddress - 0x5C00)] = aValue
            }
        }
    }
    
    mutating func ppuRead(address aAddress: UInt16) -> UInt8
    {
        self.ppuIsReading = true
        switch aAddress
        {
        case 0x0000 ...  0x1FFF:
            self.last2xxxReadAddress = 0
            self.ppu2xxxConsecutiveReadCount = 0
            self.ppuFetchesThisScanline += 1
            if self.ppuFetchesThisScanline > 34 * 16 // TODO: is this number right?
            {
                self.upperChrBankSet = false
            }
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
                if self.upperChrBankSet && self.sprite8x16ModeEnable
                {
                    let adjustedAddress: UInt16 = aAddress % 0x1000
                    let bank: Int = 8 + Int(adjustedAddress / 0x0400)
                    let offset: Int = Int(aAddress % 0x0400)
                    return self.chr[self.chrOffsets[bank] + offset]
                }
                else
                {
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
                }
                
            default:
                return 0
            }
        case 0x2000 ... 0x2FFF:
            self.ppu2xxxConsecutiveReadCount = aAddress == self.last2xxxReadAddress ? self.ppu2xxxConsecutiveReadCount + 1 : 0
            self.last2xxxReadAddress = aAddress
            if self.ppu2xxxConsecutiveReadCount == 2
            {
                self.ppuFetchesThisScanline = 0
                self.upperChrBankSet = true
                if self.inFrameFlag == false
                {
                    self.inFrameFlag = true
                    self.scanline = 0
                }
                else
                {
                    self.scanline += 1
                    if self.scanline == self.reg5203Value
                    {
                        self.pendingIRQFlag = true
                    }
                }
            }
            return 0
        default:
            os_log("unhandled Mapper_MMC5 PPU read at address (unimplemented): 0x%04X", aAddress)
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
                break
//                if self.upperChrBankSet && self.sprite8x16ModeEnable
//                {
//                    let adjustedAddress: UInt16 = aAddress % 0x1000
//                    let bank: Int = 8 + Int(adjustedAddress / 0x0400)
//                    let offset: Int = Int(aAddress % 0x0400)
//                    self.chr[self.chrOffsets[bank] + offset] = aValue
//                }
                /*else
                {
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
                }*/
            default: break
            }
        case 0x2001:
            if aValue & 0x18 == 0
            {
                self.inFrameFlag = false
                self.last2xxxReadAddress = 0
            }
        default:
            os_log("unhandled Mapper_MMC5 PPU write at address (unimplemented): 0x%04X", aAddress)
            break
        }
    }
    
    mutating func ppuControl(value aValue: UInt8)
    {
        self.ppuCtrl = aValue
        if (self.ppuCtrl >> 5) & 1 == 1,
            (self.ppuMask >> 3) & 1 == 1 || (self.ppuMask >> 4) & 1 == 1
        {
            self.sprite8x16ModeEnable = true
        }
        else
        {
            self.sprite8x16ModeEnable = false
        }
    }
    
    mutating func ppuMask(value aValue: UInt8)
    {
        self.ppuMask = aValue
        if (self.ppuCtrl >> 5) & 1 == 1,
            (self.ppuMask >> 3) & 1 == 1 || (self.ppuMask >> 4) & 1 == 1
        {
            self.sprite8x16ModeEnable = true
        }
        else
        {
            self.sprite8x16ModeEnable = false
        }
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
//        if self.ppuIsReading
//        {
//            self.idleCount = 0
//        }
//        else
//        {
//            self.idleCount += 1
//            if self.idleCount == 3
//            {
//                self.inFrameFlag = false
//                self.last2xxxReadAddress = 0
//            }
//        }
//        self.ppuIsReading = false
        
        if aMapperStepInput.ppuScanline > self.lastScanline,
           aMapperStepInput.ppuScanline == self.reg5203Value
        {
            self.irqEnableFlag = true
            self.pendingIRQFlag = true
        }
        
        
        
        self.inFrameFlag = (0 ..< 240).contains(aMapperStepInput.ppuScanline)
        
        self.lastScanline = aMapperStepInput.ppuScanline
        
        return MapperStepResults(shouldTriggerIRQOnCPU: self.pendingIRQFlag && self.irqEnableFlag)
    }
}
