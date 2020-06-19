//
//  MapperProtocol.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 6/7/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import os

protocol MapperProtocol: class
{
    var mirroringMode: MirroringMode { get }
    func read(address aAddress: UInt16) -> UInt8
    func write(address aAddress: UInt16, value aValue: UInt8)
    func step(ppu aPPU: PPUProtocol?, cpu aCPU: CPUProtocol?)
}
