//
//  PulseState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
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

struct PulseState
{
    let enabled: Bool
    let lengthEnabled: Bool
    let lengthValue: UInt8
    let timerPeriod: UInt16
    let timerValue: UInt16
    let dutyMode: UInt8
    let dutyValue: UInt8
    let sweepReload: Bool
    let sweepEnabled: Bool
    let sweepNegate: Bool
    let sweepShift: UInt8
    let sweepPeriod: UInt8
    let sweepValue: UInt8
    let envelopeEnabled: Bool
    let envelopeLoop: Bool
    let envelopeStart: Bool
    let envelopePeriod: UInt8
    let envelopeValue:  UInt8
    let envelopeVolume: UInt8
    let constantVolume: UInt8
}
