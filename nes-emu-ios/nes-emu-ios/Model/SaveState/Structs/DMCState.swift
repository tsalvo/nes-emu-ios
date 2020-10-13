//
//  DMCState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct DMCState
{
    let enabled: Bool
    let value: UInt8
    let sampleAddress: UInt16
    let sampleLength: UInt16
    let currentAddress: UInt16
    let currentLength: UInt16
    let shiftRegister: UInt8
    let bitCount: UInt8
    let tickPeriod: UInt8
    let tickValue: UInt8
    let loop: Bool
    let irq: Bool
}
