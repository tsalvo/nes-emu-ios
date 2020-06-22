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

class Mapper_MMC3: MapperProtocol
{
    let hasStep: Bool = true
    
    var mirroringMode: MirroringMode
    
    /// linear 1D array of all PRG blocks
    private var prg: [UInt8] = []
    
    /// linear 1D array of all CHR blocks
    private var chr: [UInt8] = []
    
    /// 8KB of SRAM addressible through 0x6000 ... 0x7FFF
    private var sram: [UInt8] = [UInt8].init(repeating: 0, count: 8192)
    
    var register: UInt8 = 0
    var registers: [UInt8] = [UInt8].init(repeating: 0, count: 8)
    var prgMode: UInt8 = 0
    var chrMode: UInt8 = 0
    var prgOffsets: [Int] = [Int].init(repeating: 0, count: 4)
    var chrOffsets: [Int] = [Int].init(repeating: 0, count: 8)
    var reload: UInt8 = 0
    var counter: UInt8 = 0
    var irqEnable: Bool = false
    
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

        if self.chr.count == 0
        {
            // use a block for CHR RAM if no block exists
            self.chr.append(contentsOf: [UInt8].init(repeating: 0, count: 8192))
        }

        self.prgOffsets[0] = self.prgBankOffset(index: 0)
        self.prgOffsets[1] = self.prgBankOffset(index: 1)
        self.prgOffsets[2] = self.prgBankOffset(index: -2)
        self.prgOffsets[3] = self.prgBankOffset(index: -1)
    }
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            var address = aAddress
            address = address - 0x8000
            let bank = address / 0x2000
            let offset = address % 0x2000
            return self.prg[self.prgOffsets[Int(bank)] + Int(offset)]
        case 0x6000 ..< 0x8000:
            return self.sram[Int(aAddress) - 0x6000]
        default:
            os_log("unhandled Mapper_MMC3 read at address: 0x%04X", aAddress)
            return 0
        }
    }
    
    func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        switch aAddress
        {
        case 0x8000 ... 0xFFFF:
            self.writeRegister(address: aAddress, value: aValue)
        case 0x6000 ..< 0x8000:
            self.sram[Int(aAddress) - 0x6000] = aValue
        default:
            os_log("unhandled Mapper_MMC3 write at address: 0x%04X", aAddress)
            break
        }
    }
    
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        let bank = aAddress / 0x0400
        let offset = aAddress % 0x0400
        return self.chr[self.chrOffsets[Int(bank)] + Int(offset)]
    }
    
    func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        let bank = aAddress / 0x0400
        let offset = aAddress % 0x0400
        self.chr[self.chrOffsets[Int(bank)] + Int(offset)] = aValue
    }
    
    func step(ppu aPPU: PPUProtocol?, cpu aCPU: CPUProtocol?)
    {
        guard let ppu = aPPU,
            let cpu = aCPU
        else
        {
            return
        }
        
        if ppu.cycle != 280 // TODO: this *should* be 260
        {
            return
        }
        
        if ppu.scanline > 239 && ppu.scanline < 261
        {
            return
        }
        
        if !ppu.flagShowBackground && !ppu.flagShowSprites
        {
            return
        }
        
        self.handleScanline(cpu: cpu)
    }

    private func writeRegister(address aAddress: UInt16, value aValue: UInt8)
    {
        switch aAddress
        {
        case 0x8000 ..< 0xA000:
            if aAddress % 2 == 0
            {
                self.writeBankSelect(value: aValue)
            }
            else
            {
                self.writeBankData(value: aValue)
            }
        case 0xA000 ..< 0xC000:
            if aAddress % 2 == 0
            {
                self.writeMirror(value: aValue)
            }
            else
            {
                self.writeProtect(value: aValue)
            }
        case 0xC000 ..< 0xE000:
            if aAddress % 2 == 0
            {
                self.writeIRQLatch(value: aValue)
            }
            else
            {
                self.writeIRQReload(value: aValue)
            }
        case 0xE000 ... 0xFFFF:
            if aAddress % 2 == 0
            {
                self.writeIRQDisable(value: aValue)
            }
            else
            {
                self.writeIRQEnable(value: aValue)
            }
        default: break
        }
    }

    private func writeBankSelect(value aValue: UInt8)
    {
        self.prgMode = (aValue >> 6) & 1
        self.chrMode = (aValue >> 7) & 1
        self.register = aValue & 7
        self.updateOffsets()
    }

    private func writeBankData(value aValue: UInt8)
    {
        self.registers[Int(self.register)] = aValue
        self.updateOffsets()
    }

    private func writeMirror(value aValue: UInt8)
    {
        switch aValue & 1
        {
        case 0:
            self.mirroringMode = .vertical
        case 1:
            self.mirroringMode = .horizontal
        default: break
        }
    }

    private func writeProtect(value aValue: UInt8)
    {
        
    }
    
    private func writeIRQLatch(value aValue: UInt8)
    {
        self.reload = aValue
    }

    private func writeIRQReload(value aValue: UInt8)
    {
        self.counter = 0
    }

    private func writeIRQDisable(value aValue: UInt8)
    {
        self.irqEnable = false
    }

    private func writeIRQEnable(value aValue: UInt8)
    {
        self.irqEnable = true
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
        index %= self.chr.count / 0x0400
        var offset = index * 0x0400
        if offset < 0
        {
            offset += self.chr.count
        }
        return offset
    }

    private func updateOffsets()
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
    
    private func handleScanline(cpu aCPU: CPUProtocol)
    {
        if self.counter == 0
        {
            self.counter = self.reload
        }
        else
        {
            self.counter -= 1
            
            if self.counter == 0 && self.irqEnable
            {
                aCPU.triggerIRQ()
            }
        }
    }
}

