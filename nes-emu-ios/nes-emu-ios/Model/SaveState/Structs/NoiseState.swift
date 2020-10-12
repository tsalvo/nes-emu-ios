//
//  NoiseState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct NoiseState
{
    let enabled: Bool
    let mode: Bool
    let shiftRegister: UInt16
    let lengthEnabled: Bool
    let lengthValue: UInt8
    let timerPeriod: UInt16
    let timerValue: UInt16
    let envelopeEnabled: Bool
    let envelopeLoop: Bool
    let envelopeStart: Bool
    let envelopePeriod: UInt8
    let envelopeValue: UInt8
    let envelopeVolume: UInt8
    let constantVolume: UInt8
}
