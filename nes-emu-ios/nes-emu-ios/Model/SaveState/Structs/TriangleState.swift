//
//  TriangleState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct TriangleState
{
    let enabled: Bool
    let lengthEnabled: Bool
    let lengthValue: UInt8
    let timerPeriod: UInt16
    let timerValue: UInt16
    let dutyValue: UInt8
    let counterPeriod: UInt8
    let counterValue: UInt8
    let counterReload: Bool
}
