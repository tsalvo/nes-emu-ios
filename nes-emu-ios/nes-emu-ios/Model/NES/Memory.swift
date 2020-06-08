//
//  Memory.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/5/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

protocol Memory
{
    func read(address aAddress: UInt16) -> UInt8
    func write(address aAddress: UInt16, byte aByte: UInt8)
}

class PPUMemory: Memory
{
    func read(address aAddress: UInt16) -> UInt8
    {
        // TODO: implement
        return 0
    }
    
    func write(address aAddress: UInt16, byte aByte: UInt8)
    {
        // TODO: implement
    }
    
    private func adjustedPPUAddress(forOriginalAddress aOriginalAddress: UInt16, withMirroringMode aMirrorMode: MirroringMode) -> UInt16
    {
        let address: UInt16 = (aOriginalAddress - 0x2000) % 0x1000
        let addrRange: UInt16 = address / 0x0400
        let offset: UInt16 = address % 0x0400
        return 0x2000 + aMirrorMode.nameTableOffsetSequence[Int(addrRange)] + offset
    }
}

class CPUMemory: Memory
{
    // see https://github.com/fogleman/nes/blob/master/nes/memory.go
    init(ppu aPPU: PPU, apu aAPU: APU)
    {
        self.apu = aAPU
        self.ppu = aPPU
    }
    
    /// 2KB RAM
    private var ram: [UInt8] = [UInt8].init(repeating: 0, count: 2048)
    
    private let ppu: PPU
    private let apu: APU
    
    func read(address aAddress: UInt16) -> UInt8
    {
        // TODO: implement
        return 0x00
    }
    
    func write(address aAddress: UInt16, byte aByte: UInt8)
    {
        // TODO: implement
    }
    
    
}
