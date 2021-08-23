//
//  NSManagedObject+CPUState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo.
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
    var cpuStateStruct: CPUState
    {
        get
        {
            let ram: [UInt8] = (self.value(forKeyPath: "ram") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 2048)
            let a: UInt8 = (self.value(forKeyPath: "a") as? Data)?.to(type: UInt8.self) ?? 0
            let x: UInt8 = (self.value(forKeyPath: "x") as? Data)?.to(type: UInt8.self) ?? 0
            let y: UInt8 = (self.value(forKeyPath: "y") as? Data)?.to(type: UInt8.self) ?? 0
            let pc: UInt16 = (self.value(forKeyPath: "pc") as? Data)?.to(type: UInt16.self) ?? 0
            let sp: UInt8 = (self.value(forKeyPath: "sp") as? Data)?.to(type: UInt8.self) ?? 0
            let cycles: UInt64 = (self.value(forKeyPath: "cycles") as? Data)?.to(type: UInt64.self) ?? 0
            let flags: UInt8 = (self.value(forKeyPath: "flags") as? Data)?.to(type: UInt8.self) ?? 0
            let interrupt: UInt8 = (self.value(forKeyPath: "interrupt") as? Data)?.to(type: UInt8.self) ?? 0
            let stall: UInt64 = (self.value(forKeyPath: "stall") as? Data)?.to(type: UInt64.self) ?? 0

            return CPUState.init(ram: ram, a: a, x: x, y: y, pc: pc, sp: sp, cycles: cycles, flags: flags, interrupt: interrupt, stall: stall)
        }
        set
        {
            self.setValue(Data.init(fromArray: newValue.ram), forKeyPath: "ram")
            self.setValue(Data.init(from: newValue.a), forKeyPath: "a")
            self.setValue(Data.init(from: newValue.x), forKeyPath: "x")
            self.setValue(Data.init(from: newValue.y), forKeyPath: "y")
            self.setValue(Data.init(from: newValue.pc), forKeyPath: "pc")
            self.setValue(Data.init(from: newValue.sp), forKeyPath: "sp")
            self.setValue(Data.init(from: newValue.cycles), forKeyPath: "cycles")
            self.setValue(Data.init(from: newValue.flags), forKeyPath: "flags")
            self.setValue(Data.init(from: newValue.interrupt), forKeyPath: "interrupt")
            self.setValue(Data.init(from: newValue.stall), forKeyPath: "stall")
        }
    }
}
