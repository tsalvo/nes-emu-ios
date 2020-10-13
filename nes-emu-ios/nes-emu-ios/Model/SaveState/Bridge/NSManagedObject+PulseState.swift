//
//  NSManagedObject+PulseState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject
{
    var pulseStateStruct: PulseState
    {
        get
        {
            let enabled: Bool = (self.value(forKeyPath: "enabled") as? Bool) ?? false
            let lengthEnabled: Bool = (self.value(forKeyPath: "lengthEnabled") as? Bool) ?? false
            let lengthValue: UInt8 = (self.value(forKeyPath: "lengthValue") as? Data)?.to(type: UInt8.self) ?? 0
            let timerPeriod: UInt16 = (self.value(forKeyPath: "timerPeriod") as? Data)?.to(type: UInt16.self) ?? 0
            let timerValue: UInt16 = (self.value(forKeyPath: "timerValue") as? Data)?.to(type: UInt16.self) ?? 0
            let dutyMode: UInt8 = (self.value(forKeyPath: "dutyMode") as? Data)?.to(type: UInt8.self) ?? 0
            let dutyValue: UInt8 = (self.value(forKeyPath: "dutyValue") as? Data)?.to(type: UInt8.self) ?? 0
            let sweepReload: Bool = (self.value(forKeyPath: "sweepReload") as? Bool) ?? false
            let sweepEnabled: Bool = (self.value(forKeyPath: "sweepEnabled") as? Bool) ?? false
            let sweepNegate: Bool = (self.value(forKeyPath: "sweepNegate") as? Bool) ?? false
            let sweepShift: UInt8 = (self.value(forKeyPath: "sweepShift") as? Data)?.to(type: UInt8.self) ?? 0
            let sweepPeriod: UInt8 = (self.value(forKeyPath: "sweepPeriod") as? Data)?.to(type: UInt8.self) ?? 0
            let sweepValue: UInt8 = (self.value(forKeyPath: "sweepValue") as? Data)?.to(type: UInt8.self) ?? 0
            let envelopeEnabled: Bool = (self.value(forKeyPath: "envelopeEnabled") as? Bool) ?? false
            let envelopeLoop: Bool = (self.value(forKeyPath: "envelopeLoop") as? Bool) ?? false
            let envelopeStart: Bool = (self.value(forKeyPath: "envelopeStart") as? Bool) ?? false
            let envelopePeriod: UInt8 = (self.value(forKeyPath: "envelopePeriod") as? Data)?.to(type: UInt8.self) ?? 0
            let envelopeValue:  UInt8 = (self.value(forKeyPath: "envelopeValue") as? Data)?.to(type: UInt8.self) ?? 0
            let envelopeVolume: UInt8 = (self.value(forKeyPath: "envelopeVolume") as? Data)?.to(type: UInt8.self) ?? 0
            let constantVolume: UInt8 = (self.value(forKeyPath: "constantVolume") as? Data)?.to(type: UInt8.self) ?? 0
            
            return PulseState.init(enabled: enabled, lengthEnabled: lengthEnabled, lengthValue: lengthValue, timerPeriod: timerPeriod, timerValue: timerValue, dutyMode: dutyMode, dutyValue: dutyValue, sweepReload: sweepReload, sweepEnabled: sweepEnabled, sweepNegate: sweepNegate, sweepShift: sweepShift, sweepPeriod: sweepPeriod, sweepValue: sweepValue, envelopeEnabled: envelopeEnabled, envelopeLoop: envelopeLoop, envelopeStart: envelopeStart, envelopePeriod: envelopePeriod, envelopeValue: envelopeValue, envelopeVolume: envelopeVolume, constantVolume: constantVolume)
        }
        set
        {
            self.setValue(newValue.enabled, forKeyPath: "enabled")
            self.setValue(newValue.lengthEnabled, forKeyPath: "lengthEnabled")
            self.setValue(Data.init(from: newValue.lengthValue), forKeyPath: "lengthValue")
            self.setValue(Data.init(from: newValue.timerPeriod), forKeyPath: "timerPeriod")
            self.setValue(Data.init(from: newValue.timerValue), forKeyPath: "timerValue")
            self.setValue(Data.init(from: newValue.dutyMode), forKeyPath: "dutyMode")
            self.setValue(Data.init(from: newValue.dutyValue), forKeyPath: "dutyValue")
            self.setValue(newValue.sweepReload, forKeyPath: "sweepReload")
            self.setValue(newValue.sweepEnabled, forKeyPath: "sweepEnabled")
            self.setValue(newValue.sweepNegate, forKeyPath: "sweepNegate")
            self.setValue(Data.init(from: newValue.sweepShift), forKeyPath: "sweepShift")
            self.setValue(Data.init(from: newValue.sweepPeriod), forKeyPath: "sweepPeriod")
            self.setValue(Data.init(from: newValue.sweepValue), forKeyPath: "sweepValue")
            self.setValue(newValue.envelopeEnabled, forKeyPath: "envelopeEnabled")
            self.setValue(newValue.envelopeLoop, forKeyPath: "envelopeLoop")
            self.setValue(newValue.envelopeStart, forKeyPath: "envelopeStart")
            self.setValue(Data.init(from: newValue.envelopePeriod), forKeyPath: "envelopePeriod")
            self.setValue(Data.init(from: newValue.envelopeValue), forKeyPath: "envelopeValue")
            self.setValue(Data.init(from: newValue.envelopeVolume), forKeyPath: "envelopeVolume")
            self.setValue(Data.init(from: newValue.constantVolume), forKeyPath: "constantVolume")
        }
    }
}
