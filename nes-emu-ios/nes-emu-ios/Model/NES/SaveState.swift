//
//  SaveState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 7/15/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct SaveState
{
    let cpuState: CPUState
}

struct CPUState
{
    let ram: [UInt8]
    let a: UInt8
    let x: UInt8
    let y: UInt8
    let pc: UInt16
    let cycles: UInt64
    let flags: UInt8
    let interrupt: UInt8
    let stall: Int
}
