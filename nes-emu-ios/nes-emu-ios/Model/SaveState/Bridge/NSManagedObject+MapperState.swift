//
//  NSManagedObject+MapperState.swift
//  nes-emu-ios
//
//  Created by Tom Salvo on 10/11/20.
//  Copyright © 2020 Tom Salvo. All rights reserved.
//

import Foundation
import CoreData

extension NSManagedObject
{
    var mapperStateStruct: MapperState
    {
        get
        {
            let mirroringMode: UInt8 = (self.value(forKeyPath: "mirroringMode") as? Data)?.to(type: UInt8.self) ?? 0
            let ints: [Int] = (self.value(forKeyPath: "ints") as? Data)?.toArray(type: Int.self) ?? []
            let bools: [Bool] = ((self.value(forKeyPath: "bools") as? Data)?.toArray(type: UInt8.self) ?? []).map({ $0 > 0 })
            let uint8s: [UInt8] = (self.value(forKeyPath: "uint8s") as? Data)?.toArray(type: UInt8.self) ?? []
            let chr: [UInt8] = (self.value(forKeyPath: "chr") as? Data)?.toArray(type: UInt8.self) ?? []

            return MapperState(mirroringMode: mirroringMode, ints: ints, bools: bools, uint8s: uint8s, chr: chr)
        }
        set
        {
            self.setValue(Data.init(from: newValue.mirroringMode), forKeyPath: "mirroringMode")
            self.setValue(Data.init(fromArray: newValue.ints), forKeyPath: "ints")
            self.setValue(Data.init(fromArray: newValue.bools), forKeyPath: "bools")
            self.setValue(Data.init(fromArray: newValue.uint8s), forKeyPath: "uint8s")
            self.setValue(Data.init(fromArray: newValue.chr), forKeyPath: "chr")
        }
    }
}
