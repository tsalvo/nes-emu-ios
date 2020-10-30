//
//  NSManagedObject+ConsoleState.swift
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
