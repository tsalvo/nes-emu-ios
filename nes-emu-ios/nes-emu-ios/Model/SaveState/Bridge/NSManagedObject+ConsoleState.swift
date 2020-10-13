//
//  NSManagedObject+ConsoleState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject
{
    var consoleStateStruct: ConsoleState?
    {
        guard let date: Date = self.value(forKeyPath: "date") as? Date,
            let md5: String = self.value(forKeyPath: "md5") as? String,
            let cpuState: CPUState = (self.value(forKeyPath: "cpuState") as? NSManagedObject)?.cpuStateStruct,
            let ppuState: PPUState = (self.value(forKeyPath: "ppuState") as? NSManagedObject)?.ppuStateStruct,
            let apuState: APUState = (self.value(forKeyPath: "apuState") as? NSManagedObject)?.apuStateStruct,
            let mapperState: MapperState = (self.value(forKeyPath: "mapperState") as? NSManagedObject)?.mapperStateStruct,
            let isAutoSave: Bool = self.value(forKeyPath: "isAutoSave") as? Bool
        else
        {
            return nil
        }
        
        return ConsoleState(isAutoSave: isAutoSave, date: date, md5: md5, cpuState: cpuState, apuState: apuState, ppuState: ppuState, mapperState: mapperState)
    }
}
