//
//  NSManagedObject+TriangleState.swift
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
    var triangleStateStruct: TriangleState
    {
        get
        {
            let enabled: Bool = (self.value(forKeyPath: "enabled") as? Bool) ?? false
            let lengthEnabled: Bool = (self.value(forKeyPath: "lengthEnabled") as? Bool) ?? false
            let lengthValue: UInt8 = (self.value(forKeyPath: "lengthValue") as? Data)?.to(type: UInt8.self) ?? 0
            let timerPeriod: UInt16 = (self.value(forKeyPath: "timerPeriod") as? Data)?.to(type: UInt16.self) ?? 0
            let timerValue: UInt16 = (self.value(forKeyPath: "timerValue") as? Data)?.to(type: UInt16.self) ?? 0
            let dutyValue: UInt8 = (self.value(forKeyPath: "dutyValue") as? Data)?.to(type: UInt8.self) ?? 0
            let counterPeriod: UInt8 = (self.value(forKeyPath: "counterPeriod") as? Data)?.to(type: UInt8.self) ?? 0
            let counterValue: UInt8 = (self.value(forKeyPath: "counterValue") as? Data)?.to(type: UInt8.self) ?? 0
            let counterReload: Bool = (self.value(forKeyPath: "counterReload") as? Bool) ?? false
            
            return TriangleState.init(enabled: enabled, lengthEnabled: lengthEnabled, lengthValue: lengthValue, timerPeriod: timerPeriod, timerValue: timerValue, dutyValue: dutyValue, counterPeriod: counterPeriod, counterValue: counterValue, counterReload: counterReload)
        }
        set
        {
            self.setValue(newValue.enabled, forKeyPath: "enabled")
            self.setValue(newValue.lengthEnabled, forKeyPath: "lengthEnabled")
            self.setValue(Data.init(from: newValue.lengthValue), forKeyPath: "lengthValue")
            self.setValue(Data.init(from: newValue.timerPeriod), forKeyPath: "timerPeriod")
            self.setValue(Data.init(from: newValue.timerValue), forKeyPath: "timerValue")
            self.setValue(Data.init(from: newValue.dutyValue), forKeyPath: "dutyValue")
            self.setValue(Data.init(from: newValue.counterPeriod), forKeyPath: "counterPeriod")
            self.setValue(Data.init(from: newValue.counterValue), forKeyPath: "counterValue")
            self.setValue(newValue.counterReload, forKeyPath: "counterReload")
        }
    }
}
