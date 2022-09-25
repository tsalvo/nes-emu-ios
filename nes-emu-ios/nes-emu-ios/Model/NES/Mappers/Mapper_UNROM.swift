//
//  Mapper_UNROM.swift
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

struct Mapper_UNROM: MapperProtocol
{
    // MARK: Constants
    private static let chrRamSizeInBytes: Int = 8192
    
    // MARK: - Internal Variables
    let hasStep: Bool = false
    let hasExtendedNametableMapping: Bool = false
    let mirroringMode: MirroringMode
    
    // MARK: - Private Variables
    /// linear 1D array of all PRG blocks
    private let prg: [UInt8]
    /// linear 1D array of all CHR blocks
    private let chr: [UInt8]
    /// number of 16KB PRG banks
    private let prgBanks: Int
    /// switchable 16KB PRG Bank
    private var prgBankOffset1: Int
    /// locked to last PRG block
    private let prgBankOffset2: Int
    /// if no CHR ROM banks are detected, default to 8KB CHR RAM
    private let chrRamEnabled: Bool
    /// 8KB CHR RAM for games that do not have 8KB CHR ROM
    private var chrRam: [UInt8] = [UInt8](repeating: 0, count: Mapper_UNROM.chrRamSizeInBytes)
    
    // MARK: - Life Cycle
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        var c: [UInt8] = []
        var p: [UInt8] = []
        
        for pBlock in aCartridge.prgBlocks.prefix(256) // max 256 PRG blocks (4096KB)
        {
            p.append(contentsOf: pBlock)
        }
        
        for cBlock in aCartridge.chrBlocks.prefix(1) // max 1 CHR blocks (8KB)
        {
            c.append(contentsOf: cBlock)
        }
        
        if p.isEmpty
        {
            p = [UInt8](repeating: 0, count: 0x4000)
        }
        
        self.chr = c
        self.prg = p
        
        let hasChrRam: Bool = c.isEmpty
        self.chrRamEnabled = hasChrRam
        
        if let safeState = aState,
           safeState.ints.count >= 1,
           !hasChrRam || safeState.uint8s.count >= Mapper_UNROM.chrRamSizeInBytes
        {
            self.prgBankOffset1 = safeState.ints[0]
            self.chrRam = hasChrRam ? [UInt8](safeState.uint8s[0 ..< Mapper_UNROM.chrRamSizeInBytes]) : []
        }
        else
        {
            self.prgBankOffset1 = 0
            self.chrRam = hasChrRam ? [UInt8](repeating: 0, count: Mapper_UNROM.chrRamSizeInBytes) : []
        }
        
        self.mirroringMode = aCartridge.header.mirroringMode
        
        self.prgBanks = self.prg.count / 0x4000
        self.prgBankOffset2 = (self.prgBanks - 1) * 0x4000
    }
    
    // MARK: - Save State
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: UInt8(self.mirroringMode.rawValue), ints: [self.prgBankOffset1], bools: [], uint8s: self.chrRam, chr: [])
        }
        set
        {
            guard newValue.ints.count > 0,
                  !self.chrRamEnabled || newValue.uint8s.count >= Mapper_UNROM.chrRamSizeInBytes
            else {
                return
            }
            self.chrRam = self.chrRamEnabled ? [UInt8](newValue.uint8s[0 ..< Mapper_UNROM.chrRamSizeInBytes]) : []
            self.prgBankOffset1 = newValue.ints[0]
        }
    }
    
    // MARK: - CPU Handling
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ..< 0xC000: // PRG Block 0
            return self.prg[self.prgBankOffset1 + Int(aAddress - 0x8000)]
        case 0xC000 ... 0xFFFF: // PRG Block 1 (or mirror of PRG block 0 if only one PRG exists)
            return self.prg[self.prgBankOffset2 + Int(aAddress - 0xC000)]
        case 0x6000 ..< 0x8000:
            return 0 // no PRG RAM
        default:
            os_log("unhandled Mapper_NROM read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress {
        case 0x8000 ... 0xFFFF:
            /*
            7  bit  0
            ---- ----
            xxxx pPPP
                 ||||
                 ++++- Select 16 KB PRG ROM bank for CPU $8000-$BFFF
                      (UNROM uses bits 2-0; UOROM uses bits 3-0)
             Emulator implementations of iNES mapper 2 treat this as a full 8-bit
             bank select register, without bus conflicts. This allows the mapper
             to be used for similar boards that are compatible.
             */
            self.prgBankOffset1 = (Int(aValue) % self.prgBanks) * 0x4000
        case 0x6000 ... 0x7FFF:
            // no PRG RAM
            break
        default:
            os_log("unhandled Mapper_NROM write at address: 0x%04X", aAddress)
            break
        }
    }
    // MARK: - PPU Handling
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        if self.chrRamEnabled
        {
            return self.chrRam[Int(aAddress)]
        }
        else
        {
            return self.chr[Int(aAddress)]
        }
    }
        
    
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        if self.chrRamEnabled
        {
            self.chrRam[Int(aAddress)] = aValue
        }
    }
    
    // MARK: - Step
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
