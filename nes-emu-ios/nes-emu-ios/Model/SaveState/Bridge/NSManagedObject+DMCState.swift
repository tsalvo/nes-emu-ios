//
//  NSManagedObject+DMCState.swift
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
import CoreData

extension NSManagedObject
{
    var dmcStateStruct: DMCState
    {
        get
        {
            let enabled: Bool = (self.value(forKeyPath: "enabled") as? Bool) ?? false
            let value: UInt8 = (self.value(forKeyPath: "value") as? Data)?.to(type: UInt8.self) ?? 0
            let sampleAddress: UInt16 = (self.value(forKeyPath: "sampleAddress") as? Data)?.to(type: UInt16.self) ?? 0
            let sampleLength: UInt16 = (self.value(forKeyPath: "sampleLength") as? Data)?.to(type: UInt16.self) ?? 0
            let currentAddress: UInt16 = (self.value(forKeyPath: "currentAddress") as? Data)?.to(type: UInt16.self) ?? 0
            let currentLength: UInt16 = (self.value(forKeyPath: "currentLength") as? Data)?.to(type: UInt16.self) ?? 0
            let shiftRegister: UInt8 = (self.value(forKeyPath: "shiftRegister") as? Data)?.to(type: UInt8.self) ?? 0
            let bitCount: UInt8 = (self.value(forKeyPath: "bitCount") as? Data)?.to(type: UInt8.self) ?? 0
            let tickPeriod: UInt8 = (self.value(forKeyPath: "tickPeriod") as? Data)?.to(type: UInt8.self) ?? 0
            let tickValue: UInt8 = (self.value(forKeyPath: "tickValue") as? Data)?.to(type: UInt8.self) ?? 0
            let loop: Bool = (self.value(forKeyPath: "loop") as? Bool) ?? false
            let irq: Bool = (self.value(forKeyPath: "irq") as? Bool) ?? false
            
            return DMCState(enabled: enabled, value: value, sampleAddress: sampleAddress, sampleLength: sampleLength, currentAddress: currentAddress, currentLength: currentLength, shiftRegister: shiftRegister, bitCount: bitCount, tickPeriod: tickPeriod, tickValue: tickValue, loop: loop, irq: irq)
        }
        set
        {
            self.setValue(newValue.enabled, forKeyPath: "enabled")
            self.setValue(Data.init(from: newValue.sampleAddress), forKeyPath: "sampleAddress")
            self.setValue(Data.init(from: newValue.sampleLength), forKeyPath: "sampleLength")
            self.setValue(Data.init(from: newValue.currentAddress), forKeyPath: "currentAddress")
            self.setValue(Data.init(from: newValue.currentLength), forKeyPath: "currentLength")
            self.setValue(Data.init(from: newValue.shiftRegister), forKeyPath: "shiftRegister")
            self.setValue(Data.init(from: newValue.bitCount), forKeyPath: "bitCount")
            self.setValue(Data.init(from: newValue.tickPeriod), forKeyPath: "tickPeriod")
            self.setValue(Data.init(from: newValue.tickValue), forKeyPath: "tickValue")
            self.setValue(newValue.loop, forKeyPath: "loop")
            self.setValue(newValue.irq, forKeyPath: "irq")
        }
    }
}
