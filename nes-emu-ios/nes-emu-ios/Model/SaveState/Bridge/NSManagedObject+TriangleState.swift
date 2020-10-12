//
//  NSManagedObject+TriangleState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

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
