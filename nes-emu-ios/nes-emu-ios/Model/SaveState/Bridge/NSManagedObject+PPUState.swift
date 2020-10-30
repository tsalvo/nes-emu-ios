//
//  NSManagedObject+PPUState.swift
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
    var ppuStateStruct: PPUState
    {
        get
        {
            let cycle: UInt16 = (self.value(forKeyPath: "cycle") as? Data)?.to(type: UInt16.self) ?? 0
            let scanline: UInt16 = (self.value(forKeyPath: "scanline") as? Data)?.to(type: UInt16.self) ?? 0
            let frame: UInt64 = (self.value(forKeyPath: "frame") as? Data)?.to(type: UInt64.self) ?? 0
            let paletteData: [UInt8] = (self.value(forKeyPath: "paletteData") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 32)
            let nameTableData: [UInt8] = (self.value(forKeyPath: "nameTableData") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 2048)
            let oamData: [UInt8] = (self.value(forKeyPath: "oamData") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 256)
            let v: UInt16 = (self.value(forKeyPath: "v") as? Data)?.to(type: UInt16.self) ?? 0
            let t: UInt16 = (self.value(forKeyPath: "t") as? Data)?.to(type: UInt16.self) ?? 0
            let x: UInt8 = (self.value(forKeyPath: "x") as? Data)?.to(type: UInt8.self) ?? 0
            let w: Bool = (self.value(forKeyPath: "w") as? Bool) ?? false
            let f: Bool = (self.value(forKeyPath: "f") as? Bool) ?? false
            let register: UInt8 = (self.value(forKeyPath: "register") as? Data)?.to(type: UInt8.self) ?? 0
            let nmiOccurred: Bool = (self.value(forKeyPath: "nmiOccurred") as? Bool) ?? false
            let nmiOutput: Bool = (self.value(forKeyPath: "nmiOutput") as? Bool) ?? false
            let nmiPrevious: Bool = (self.value(forKeyPath: "nmiPrevious") as? Bool) ?? false
            let nmiDelay: UInt8 = (self.value(forKeyPath: "nmiDelay") as? Data)?.to(type: UInt8.self) ?? 0
            let nameTableByte: UInt8 = (self.value(forKeyPath: "nameTableByte") as? Data)?.to(type: UInt8.self) ?? 0
            let attributeTableByte: UInt8 = (self.value(forKeyPath: "attributeTableByte") as? Data)?.to(type: UInt8.self) ?? 0
            let lowTileByte: UInt8 = (self.value(forKeyPath: "lowTileByte") as? Data)?.to(type: UInt8.self) ?? 0
            let highTileByte: UInt8 = (self.value(forKeyPath: "highTileByte") as? Data)?.to(type: UInt8.self) ?? 0
            let tileData: UInt64 = (self.value(forKeyPath: "tileData") as? Data)?.to(type: UInt64.self) ?? 0
            let spriteCount: UInt8 = (self.value(forKeyPath: "spriteCount") as? Data)?.to(type: UInt8.self) ?? 0
            let spritePatterns: [UInt32] = (self.value(forKeyPath: "spritePatterns") as? Data)?.toArray(type: UInt32.self) ?? [UInt32].init(repeating: 0, count: 8)
            let spritePositions: [UInt8] = (self.value(forKeyPath: "spritePositions") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 8)
            let spritePriorities: [UInt8] = (self.value(forKeyPath: "spritePriorities") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 8)
            let spriteIndexes: [UInt8] = (self.value(forKeyPath: "spriteIndexes") as? Data)?.toArray(type: UInt8.self) ?? [UInt8].init(repeating: 0, count: 8)
            let flagNameTable: UInt8 = (self.value(forKeyPath: "flagNameTable") as? Data)?.to(type: UInt8.self) ?? 0
            let flagIncrement: Bool = (self.value(forKeyPath: "flagIncrement") as? Bool) ?? false
            let flagSpriteTable: Bool = (self.value(forKeyPath: "flagSpriteTable") as? Bool) ?? false
            let flagBackgroundTable: Bool = (self.value(forKeyPath: "flagBackgroundTable") as? Bool) ?? false
            let flagSpriteSize: Bool = (self.value(forKeyPath: "flagSpriteSize") as? Bool) ?? false
            let flagMasterSlave: Bool = (self.value(forKeyPath: "flagMasterSlave") as? Bool) ?? false
            let flagGrayscale: Bool = (self.value(forKeyPath: "flagGrayscale") as? Bool) ?? false
            let flagShowLeftBackground: Bool = (self.value(forKeyPath: "flagShowLeftBackground") as? Bool) ?? false
            let flagShowLeftSprites: Bool = (self.value(forKeyPath: "flagShowLeftSprites") as? Bool) ?? false
            let flagShowBackground: Bool = (self.value(forKeyPath: "flagShowBackground") as? Bool) ?? false
            let flagShowSprites: Bool = (self.value(forKeyPath: "flagShowSprites") as? Bool) ?? false
            let flagRedTint: Bool = (self.value(forKeyPath: "flagRedTint") as? Bool) ?? false
            let flagGreenTint: Bool = (self.value(forKeyPath: "flagGreenTint") as? Bool) ?? false
            let flagBlueTint: Bool = (self.value(forKeyPath: "flagBlueTint") as? Bool) ?? false
            let flagSpriteZeroHit: UInt8 = (self.value(forKeyPath: "flagSpriteZeroHit") as? Data)?.to(type: UInt8.self) ?? 0
            let flagSpriteOverflow: UInt8 = (self.value(forKeyPath: "flagSpriteOverflow") as? Data)?.to(type: UInt8.self) ?? 0
            let oamAddress: UInt8 = (self.value(forKeyPath: "oamAddress") as? Data)?.to(type: UInt8.self) ?? 0
            let bufferedData: UInt8 = (self.value(forKeyPath: "bufferedData") as? Data)?.to(type: UInt8.self) ?? 0
            let frontBuffer: [UInt32] = (self.value(forKeyPath: "frontBuffer") as? Data)?.toArray(type: UInt32.self) ?? PPU.emptyBuffer

            return PPUState(cycle: cycle, scanline: scanline, frame: frame, paletteData: paletteData, nameTableData: nameTableData, oamData: oamData, v: v, t: t, x: x, w: w, f: f, register: register, nmiOccurred: nmiOccurred, nmiOutput: nmiOutput, nmiPrevious: nmiPrevious, nmiDelay: nmiDelay, nameTableByte: nameTableByte, attributeTableByte: attributeTableByte, lowTileByte: lowTileByte, highTileByte: highTileByte, tileData: tileData, spriteCount: spriteCount, spritePatterns: spritePatterns, spritePositions: spritePositions, spritePriorities: spritePriorities, spriteIndexes: spriteIndexes, flagNameTable: flagNameTable, flagIncrement: flagIncrement, flagSpriteTable: flagSpriteTable, flagBackgroundTable: flagBackgroundTable, flagSpriteSize: flagSpriteSize, flagMasterSlave: flagMasterSlave, flagGrayscale: flagGrayscale, flagShowLeftBackground: flagShowLeftBackground, flagShowLeftSprites: flagShowLeftSprites, flagShowBackground: flagShowBackground, flagShowSprites: flagShowSprites, flagRedTint: flagRedTint, flagGreenTint: flagGreenTint, flagBlueTint: flagBlueTint, flagSpriteZeroHit: flagSpriteZeroHit, flagSpriteOverflow: flagSpriteOverflow, oamAddress: oamAddress, bufferedData: bufferedData, frontBuffer: frontBuffer)
        }
        set
        {
            self.setValue(Data.init(from: newValue.cycle), forKeyPath: "cycle")
            self.setValue(Data.init(from: newValue.scanline), forKeyPath: "scanline")
            self.setValue(Data.init(from: newValue.frame), forKeyPath: "frame")
            self.setValue(Data.init(fromArray: newValue.paletteData), forKeyPath: "paletteData")
            self.setValue(Data.init(fromArray: newValue.nameTableData), forKeyPath: "nameTableData")
            self.setValue(Data.init(fromArray: newValue.oamData), forKeyPath: "oamData")
            self.setValue(Data.init(from: newValue.v), forKeyPath: "v")
            self.setValue(Data.init(from: newValue.t), forKeyPath: "t")
            self.setValue(Data.init(from: newValue.x), forKeyPath: "x")
            self.setValue(newValue.w, forKeyPath: "w")
            self.setValue(newValue.f, forKeyPath: "f")
            self.setValue(Data.init(from: newValue.register), forKeyPath: "register")
            self.setValue(newValue.nmiOccurred, forKeyPath: "nmiOccurred")
            self.setValue(newValue.nmiOutput, forKeyPath: "nmiOutput")
            self.setValue(newValue.nmiPrevious, forKeyPath: "nmiPrevious")
            self.setValue(Data.init(from: newValue.nmiDelay), forKeyPath: "nmiDelay")
            self.setValue(Data.init(from: newValue.nameTableByte), forKeyPath: "nameTableByte")
            self.setValue(Data.init(from: newValue.attributeTableByte), forKeyPath: "attributeTableByte")
            self.setValue(Data.init(from: newValue.lowTileByte), forKeyPath: "lowTileByte")
            self.setValue(Data.init(from: newValue.highTileByte), forKeyPath: "highTileByte")
            self.setValue(Data.init(from: newValue.tileData), forKeyPath: "tileData")
            self.setValue(Data.init(from: newValue.spriteCount), forKeyPath: "spriteCount")
            self.setValue(Data.init(fromArray: newValue.spritePatterns), forKeyPath: "spritePatterns")
            self.setValue(Data.init(fromArray: newValue.spritePositions), forKeyPath: "spritePositions")
            self.setValue(Data.init(fromArray: newValue.spritePriorities), forKeyPath: "spritePriorities")
            self.setValue(Data.init(fromArray: newValue.spriteIndexes), forKeyPath: "spriteIndexes")
            self.setValue(Data.init(from: newValue.flagNameTable), forKeyPath: "flagNameTable")
            self.setValue(newValue.flagIncrement, forKeyPath: "flagIncrement")
            self.setValue(newValue.flagSpriteTable, forKeyPath: "flagSpriteTable")
            self.setValue(newValue.flagBackgroundTable, forKeyPath: "flagBackgroundTable")
            self.setValue(newValue.flagSpriteSize, forKeyPath: "flagSpriteSize")
            self.setValue(newValue.flagMasterSlave, forKeyPath: "flagMasterSlave")
            self.setValue(newValue.flagGrayscale, forKeyPath: "flagGrayscale")
            self.setValue(newValue.flagShowLeftBackground, forKeyPath: "flagShowLeftBackground")
            self.setValue(newValue.flagShowLeftSprites, forKeyPath: "flagShowLeftSprites")
            self.setValue(newValue.flagShowBackground, forKeyPath: "flagShowBackground")
            self.setValue(newValue.flagShowSprites, forKeyPath: "flagShowSprites")
            self.setValue(newValue.flagRedTint, forKeyPath: "flagRedTint")
            self.setValue(newValue.flagGreenTint, forKeyPath: "flagGreenTint")
            self.setValue(newValue.flagBlueTint, forKeyPath: "flagBlueTint")
            self.setValue(Data.init(from: newValue.flagSpriteZeroHit), forKeyPath: "flagSpriteZeroHit")
            self.setValue(Data.init(from: newValue.flagSpriteOverflow), forKeyPath: "flagSpriteOverflow")
            self.setValue(Data.init(from: newValue.oamAddress), forKeyPath: "oamAddress")
            self.setValue(Data.init(from: newValue.bufferedData), forKeyPath: "bufferedData")
            self.setValue(Data.init(fromArray: newValue.frontBuffer), forKeyPath: "frontBuffer")
        }
    }
}
