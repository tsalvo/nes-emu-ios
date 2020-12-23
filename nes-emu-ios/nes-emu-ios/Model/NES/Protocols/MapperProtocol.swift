//
//  MapperProtocol.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/7/20.
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

struct MapperStepResults
{
    let shouldTriggerIRQOnCPU: Bool
}

struct MapperStepInput
{
    let ppuScanline: Int
    let ppuCycle: Int
    let ppuShowBackground: Bool
    let ppuShowSprites: Bool
}

protocol MapperProtocol
{
    /// returns a Bool indicating whether the step function returns anything
    var hasStep: Bool { get }
    
    /// returns the current mirroring mode for the mapper.  the mirroring mode is initially set to whatever the NES ROM iNES header specifies, but some mappers allow this to be changed at runtime
    var mirroringMode: MirroringMode { get }
    
    var mapperState: MapperState { get set }
    
    /// read a given mapper address from the CPU (must be an address in the range 0x6000 ... 0xFFFF)
    mutating func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    
    /// write to a given mapper address from the CPU (must be an address in the range 0x5000 ... 0xFFFF)
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    
    /// read a given mapper address from the PPU (must be an address in the range 0x0000 ... 0x1FFF)
    mutating func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    
    /// write to a given mapper address from the PPU (must be an address in the range 0x0000 ... 0x1FFF)
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    
    /// relay a PPU write of address 0x2000 (PPUCTRL) to the mapper
    mutating func ppuControl(value aValue: UInt8) // 0x2000
    
    /// relay a PPU write of address 0x2001 (PPUMASK) to the mapper
    mutating func ppuMask(value aValue: UInt8) // 0x2001
    
    /// run a single cycle on the mapper, corresponding with a PPU cycle, if the mapper needs to interface with the CPU or PPU
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
}
