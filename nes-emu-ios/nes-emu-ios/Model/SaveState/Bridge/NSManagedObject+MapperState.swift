//
//  NSManagedObject+MapperState.swift
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
