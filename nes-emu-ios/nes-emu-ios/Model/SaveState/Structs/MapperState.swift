//
//  MapperState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/10/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct MapperState
{
    let mirroringMode: UInt8
    let ints: [Int]
    let bools: [Bool]
    let uint8s: [UInt8]
    let chr: [UInt8]
}
