//
//  APUState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/10/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation

struct APUState
{
    let cycle: UInt64
    let framePeriod: UInt8
    let frameValue: UInt8
    let frameIRQ: Bool
    let audioBuffer: [Float32]
    let audioBufferIndex: UInt32
    let pulse1: PulseState
    let pulse2: PulseState
    let triangle: TriangleState
    let noise: NoiseState
    let dmc: DMCState
}
