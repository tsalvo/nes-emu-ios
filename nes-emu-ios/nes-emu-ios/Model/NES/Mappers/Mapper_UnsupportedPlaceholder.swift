//
//  Mapper_UnsupportedPlaceholder.swift
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

struct Mapper_UnsupportedPlaceholder: MapperProtocol
{
    let hasStep: Bool = false
    
    let hasExtendedNametableMapping: Bool = false
    
    init(withCartridge aCartridge: CartridgeProtocol, state aState: MapperState? = nil)
    {
        if let safeState = aState
        {
            self.mirroringMode = MirroringMode.init(rawValue: Int(safeState.mirroringMode)) ?? aCartridge.header.mirroringMode
        }
        else
        {
            self.mirroringMode = aCartridge.header.mirroringMode
        }
    }
    
    var mapperState: MapperState
    {
        get
        {
            MapperState(mirroringMode: UInt8(self.mirroringMode.rawValue), ints: [], bools: [], uint8s: [], chr: [])
        }
        set
        {
            
        }
    }
    
    let mirroringMode: MirroringMode
    
    func cpuRead(address aAddress: UInt16) -> UInt8 // 0x6000 ... 0xFFFF
    {
        return 0
    }
    
    /// write to a given mapper address from the CPU (must be an address in the range 0x6000 ... 0xFFFF)
    mutating func cpuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x6000 ... 0xFFFF
    {
        
    }
    
    /// read a given mapper address from the PPU (must be an address in the range 0x0000 ... 0x1FFF)
    func ppuRead(address aAddress: UInt16) -> UInt8 // 0x0000 ... 0x1FFF
    {
        return 0
    }
    
    /// write to a given mapper address from the PPU (must be an address in the range 0x0000 ... 0x1FFF)
    mutating func ppuWrite(address aAddress: UInt16, value aValue: UInt8) // 0x0000 ... 0x1FFF
    {
        
    }
    
    mutating func step(input aMapperStepInput: MapperStepInput) -> MapperStepResults?
    {
        return nil
    }
}
