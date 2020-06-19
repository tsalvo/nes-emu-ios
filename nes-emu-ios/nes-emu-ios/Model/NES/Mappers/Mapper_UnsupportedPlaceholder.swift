//
//  Mapper_UnsupportedPlaceholder.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/18/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

class Mapper_UnsupportedPlaceholder: MapperProtocol
{
    init(withCartridge aCartridge: CartridgeProtocol)
    {
        self.mirroringMode = aCartridge.header.mirroringMode
    }
    
    let mirroringMode: MirroringMode
    
    func read(address aAddress: UInt16) -> UInt8
    {
        return 0
    }
    
    func write(address aAddress: UInt16, value aValue: UInt8) { }
    
    func step(ppu aPPU: PPUProtocol?, cpu aCPU: CPUProtocol?) { }
}
